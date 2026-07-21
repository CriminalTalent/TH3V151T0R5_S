# mastodon_client.rb
# encoding: UTF-8

require 'net/http'
require 'json'
require 'uri'
require 'time'
require 'open-uri'
require 'tempfile'
require 'openssl'
require 'securerandom'

class MastodonClient
  MAX_CHARS = 1000

  def initialize(base_url:, token:)
    @base_url = base_url.to_s.sub(%r{/\z}, '')
    @token    = token.to_s

    setup_http

    @post_block_until = Time.at(0)
  end

  # --------------------------------------------------
  # HTTP 연결 생성
  # --------------------------------------------------
  def setup_http
    uri = URI(@base_url)

    @http = Net::HTTP.new(uri.host, uri.port)
    @http.use_ssl = (uri.scheme == 'https')
    @http.keep_alive_timeout = 30
    @http.open_timeout = 10
    @http.read_timeout = 30
    @http.write_timeout = 30 if @http.respond_to?(:write_timeout=)
  end

  # --------------------------------------------------
  # 문자열을 안전한 UTF-8로 정리
  #
  # 주의:
  # @계정명 같은 멘션 문자열은 제거하거나 변형하지 않는다.
  # --------------------------------------------------
  def safe_utf8(str)
    return '' if str.nil?

    string = str.to_s.dup
    string.force_encoding('UTF-8')

    return string if string.valid_encoding?

    string.encode(
      'UTF-8',
      'binary',
      invalid: :replace,
      undef: :replace,
      replace: '?'
    )
  rescue => e
    puts "[UTF-8 오류] #{e.class} - #{e.message}"
    str.to_s
  end

  # --------------------------------------------------
  # Mastodon API 요청
  # --------------------------------------------------
  def request(method:, path:, params: {}, form: nil, headers: {})
    perform_request(
      method: method,
      path: path,
      params: params,
      form: form,
      headers: headers
    )
  rescue EOFError,
         IOError,
         Errno::ECONNRESET,
         Errno::EPIPE,
         Net::OpenTimeout,
         Net::ReadTimeout => e
    puts "[HTTP 연결 오류] #{e.class} - #{e.message}"
    puts '[HTTP] 연결을 다시 만든 뒤 1회 재시도합니다.'

    setup_http

    begin
      perform_request(
        method: method,
        path: path,
        params: params,
        form: form,
        headers: headers
      )
    rescue => retry_error
      puts(
        "[HTTP 재시도 실패] " \
        "#{retry_error.class} - #{retry_error.message}"
      )

      [nil, {}]
    end
  rescue => e
    puts "[HTTP 오류] #{e.class} - #{e.message}"
    [nil, {}]
  end

  # --------------------------------------------------
  # 알림 조회
  # --------------------------------------------------
  def notifications(
    limit: 30,
    since_id: nil,
    max_id: nil,
    min_id: nil,
    types: nil,
    exclude_types: nil
  )
    params = {}

    params[:limit]    = limit.to_i if limit
    params[:since_id] = since_id.to_s if since_id
    params[:max_id]   = max_id.to_s if max_id
    params[:min_id]   = min_id.to_s if min_id

    if types&.respond_to?(:each)
      types.each_with_index do |type, index|
        params["types[#{index}]"] = type.to_s
      end
    end

    if exclude_types&.respond_to?(:each)
      exclude_types.each_with_index do |type, index|
        params["exclude_types[#{index}]"] = type.to_s
      end
    end

    res, body = request(
      method: :get,
      path: '/api/v1/notifications',
      params: params
    )

    unless successful_response?(res)
      log_api_failure('NOTIFICATIONS', res, body)
      return []
    end

    body.is_a?(Array) ? body : []
  end

  # --------------------------------------------------
  # 이미지 MIME 타입 확인
  # --------------------------------------------------
  def content_type_for(path)
    ext = File.extname(path.to_s).downcase

    case ext
    when '.png'
      'image/png'
    when '.webp'
      'image/webp'
    when '.gif'
      'image/gif'
    when '.jpg', '.jpeg'
      'image/jpeg'
    else
      'image/jpeg'
    end
  end

  # --------------------------------------------------
  # Google Drive 공유 URL을 다운로드 URL로 변환
  # --------------------------------------------------
  def normalize_download_url(url)
    value = url.to_s.strip

    if value =~ %r{/file/d/([^/]+)}
      file_id = Regexp.last_match(1)

      return(
        "https://drive.google.com/uc?" \
        "export=download&id=#{file_id}"
      )
    end

    if value.include?('drive.google.com') && value.include?('id=')
      begin
        uri = URI(value)
        query = URI.decode_www_form(uri.query || '').to_h
        file_id = query['id'].to_s.strip

        unless file_id.empty?
          return(
            "https://drive.google.com/uc?" \
            "export=download&id=#{file_id}"
          )
        end
      rescue => e
        puts(
          "[다운로드 URL 변환 오류] " \
          "#{e.class} - #{e.message}"
        )
      end
    end

    value
  end

  # --------------------------------------------------
  # URL에서 이미지를 내려받은 뒤 업로드
  # --------------------------------------------------
  def upload_media_from_url(image_url, description: nil)
    download_url = normalize_download_url(image_url)

    if download_url.empty?
      puts '[MEDIA-URL 오류] 이미지 URL이 비어 있습니다.'
      return nil
    end

    path_without_query = begin
      URI(download_url).path
    rescue
      download_url
    end

    ext = File.extname(path_without_query.to_s)
    ext = '.png' if ext.empty?

    Tempfile.create(['doll', ext]) do |file|
      file.binmode

      URI.open(
        download_url,
        'User-Agent' => 'Mozilla/5.0',
        open_timeout: 15,
        read_timeout: 30
      ) do |io|
        file.write(io.read)
      end

      file.flush
      file.rewind

      upload_media(
        file.path,
        description: description
      )
    end
  rescue => e
    puts "[MEDIA-URL 오류] #{e.class} - #{e.message}"
    nil
  end

  # --------------------------------------------------
  # 이미지 파일 업로드
  # --------------------------------------------------
  def upload_media(path, description: nil)
    unless File.file?(path.to_s)
      puts "[MEDIA] 파일을 찾을 수 없습니다: #{path}"
      return nil
    end

    uri = URI.join(@base_url, '/api/v2/media')
    boundary = SecureRandom.hex(16)

    filename = File.basename(path.to_s)
    file_bin = File.binread(path.to_s)
    content_type = content_type_for(path)

    body = +''
    body.force_encoding(Encoding::BINARY)

    body << "--#{boundary}\r\n"
    body <<(
      "Content-Disposition: form-data; " \
      "name=\"file\"; filename=\"#{filename}\"\r\n"
    )
    body << "Content-Type: #{content_type}\r\n\r\n"
    body << file_bin
    body << "\r\n"

    unless description.to_s.strip.empty?
      body << "--#{boundary}\r\n"
      body <<(
        "Content-Disposition: form-data; " \
        "name=\"description\"\r\n\r\n"
      )
      body << safe_utf8(description)
      body << "\r\n"
    end

    body << "--#{boundary}--\r\n"

    req = Net::HTTP::Post.new(uri)
    req['Authorization'] = "Bearer #{@token}"
    req['Content-Type'] =
      "multipart/form-data; boundary=#{boundary}"
    req.body = body

    res = @http.request(req)

    unless successful_response?(res)
      puts(
        "[MEDIA] 업로드 실패 " \
        "code=#{res.code} " \
        "body=#{res.body.to_s[0, 500]}"
      )

      return nil
    end

    response_body = begin
      JSON.parse(res.body)
    rescue JSON::ParserError
      {}
    end

    media_id = response_body['id']

    unless media_id
      puts '[MEDIA] 응답에 media ID가 없습니다.'
      return nil
    end

    # 202이면 서버에서 미디어 처리 중일 수 있으므로
    # 최대 10초 동안 완료 여부를 확인한다.
    if res.code.to_i == 202
      wait_for_media_processing(media_id)
    end

    media_id
  rescue EOFError,
         IOError,
         Errno::ECONNRESET,
         Errno::EPIPE,
         Net::OpenTimeout,
         Net::ReadTimeout => e
    puts "[MEDIA 연결 오류] #{e.class} - #{e.message}"
    setup_http
    nil
  rescue => e
    puts "[MEDIA 업로드 오류] #{e.class} - #{e.message}"
    nil
  end

  # --------------------------------------------------
  # 상태 게시
  #
  # 전달받은 text를 그대로 게시한다.
  # @sender, @target 등의 멘션을 삭제하거나 바꾸지 않는다.
  #
  # 1000자를 초과하면 답글 스레드로 분할한다.
  # --------------------------------------------------
  def post_status(
    text,
    reply_to_id: nil,
    visibility: 'public',
    media_ids: []
  )
    if Time.now < @post_block_until
      puts(
        "[POST] 게시 제한 중입니다. " \
        "#{@post_block_until} 이후 다시 시도할 수 있습니다."
      )

      return nil
    end

    normalized_text = safe_utf8(text).strip

    if normalized_text.empty?
      puts '[POST] 빈 메시지는 게시하지 않습니다.'
      return nil
    end

    chunks = split_text(normalized_text)

    last_response = nil
    current_reply_id = reply_to_id

    chunks.each_with_index do |chunk, index|
      form = [
        ['status', chunk],
        ['visibility', visibility.to_s]
      ]

      if current_reply_id &&
         !current_reply_id.to_s.strip.empty?
        form << [
          'in_reply_to_id',
          current_reply_id.to_s
        ]
      end

      Array(media_ids).compact.each do |media_id|
        next if media_id.to_s.strip.empty?

        form << ['media_ids[]', media_id.to_s]
      end

      res, body = request(
        method: :post,
        path: '/api/v1/statuses',
        form: form
      )

      unless res
        puts(
          "[POST] 응답 없음 " \
          "chunk=#{index + 1}/#{chunks.length}"
        )

        break
      end

      if res.code.to_i == 429
        apply_post_rate_limit(res)
        break
      end

      unless successful_response?(res)
        log_api_failure(
          "POST chunk=#{index + 1}/#{chunks.length}",
          res,
          body
        )

        break
      end

      unless body.is_a?(Hash) && body['id']
        puts(
          "[POST] 게시 성공 응답에 status ID가 없습니다. " \
          "chunk=#{index + 1}/#{chunks.length}"
        )

        last_response = res
        break
      end

      # 다음 청크를 방금 게시한 툿의 답글로 연결한다.
      current_reply_id = body['id']
      last_response = res

      sleep 1 if chunks.length > 1
    end

    last_response
  rescue => e
    puts "[POST 오류] #{e.class} - #{e.message}"
    nil
  end

  # --------------------------------------------------
  # 특정 상태에 답글 게시
  #
  # in_reply_to_id는 대화 연결용이다.
  # 실제 태그 대상은 text 안에 @계정 형식으로 들어 있어야 한다.
  # --------------------------------------------------
  def reply(
    status,
    text,
    visibility: 'unlisted',
    media_ids: []
  )
    reply_id =
      if status.is_a?(Hash)
        status['id'] || status[:id]
      else
        status
      end

    post_status(
      text,
      reply_to_id: reply_id,
      visibility: visibility,
      media_ids: media_ids
    )
  end

  private

  # --------------------------------------------------
  # 실제 HTTP 요청 실행
  # --------------------------------------------------
  def perform_request(
    method:,
    path:,
    params: {},
    form: nil,
    headers: {}
  )
    uri = URI.join(@base_url, path)

    if method == :get && params&.any?
      uri.query = URI.encode_www_form(params)
    end

    base_headers = {
      'Authorization' => "Bearer #{@token}",
      'Accept' => 'application/json'
    }.merge(headers || {})

    req =
      case method
      when :get
        Net::HTTP::Get.new(uri, base_headers)
      when :post
        request = Net::HTTP::Post.new(uri, base_headers)
        request.set_form_data(form) if form
        request
      else
        raise ArgumentError, "Unsupported method: #{method}"
      end

    res = @http.request(req)

    body = begin
      JSON.parse(res.body.to_s)
    rescue JSON::ParserError
      {}
    end

    [res, body]
  end

  # --------------------------------------------------
  # HTTP 성공 여부
  # --------------------------------------------------
  def successful_response?(response)
    response &&
      response.code.to_i.between?(200, 299)
  end

  # --------------------------------------------------
  # API 실패 내용 출력
  # --------------------------------------------------
  def log_api_failure(label, response, body)
    unless response
      puts "[#{label}] API 응답이 없습니다."
      return
    end

    parsed_body =
      if body.is_a?(Hash) || body.is_a?(Array)
        body.inspect
      else
        body.to_s
      end

    puts(
      "[#{label}] API 실패 " \
      "code=#{response.code} " \
      "body=#{parsed_body[0, 500]}"
    )
  end

  # --------------------------------------------------
  # 게시 제한 시간 반영
  # --------------------------------------------------
  def apply_post_rate_limit(response)
    reset = response['x-ratelimit-reset']

    @post_block_until =
      begin
        reset && !reset.empty? \
          ? Time.parse(reset)
          : Time.now + 600
      rescue
        Time.now + 600
      end

    puts(
      "[POST] rate limit → " \
      "#{@post_block_until}까지 게시를 중단합니다."
    )
  end

  # --------------------------------------------------
  # 미디어 처리 완료 대기
  # --------------------------------------------------
  def wait_for_media_processing(media_id)
    5.times do
      sleep 2

      res, = request(
        method: :get,
        path: "/api/v1/media/#{media_id}"
      )

      return true if successful_response?(res)
    end

    puts(
      "[MEDIA] 처리 완료를 확인하지 못했습니다. " \
      "media_id=#{media_id}"
    )

    false
  end

  # --------------------------------------------------
  # 긴 텍스트 분할
  #
  # 우선순위:
  # 1. 줄바꿈
  # 2. 공백
  # 3. 최대 글자 수
  #
  # 공백 기준도 사용하여 @계정 문자열 한가운데가
  # 잘릴 가능성을 줄인다.
  # --------------------------------------------------
  def split_text(text)
    return [text] if text.length <= MAX_CHARS

    chunks = []
    remaining = text.dup

    while remaining.length > MAX_CHARS
      slice = remaining[0, MAX_CHARS]

      cut =
        slice.rindex("\n") ||
        slice.rindex(' ') ||
        MAX_CHARS

      # 첫 부분에만 공백이나 줄바꿈이 있는 경우
      # 지나치게 짧은 청크가 만들어지는 것을 방지한다.
      cut = MAX_CHARS if cut < (MAX_CHARS / 2)

      chunk = remaining[0, cut].rstrip

      unless chunk.empty?
        chunks << chunk
      end

      remaining = remaining[cut..].to_s.lstrip
    end

    chunks << remaining unless remaining.empty?
    chunks
  end
end

# ─────────────────────────────────────────────
# 이미지 다운로드/업로드 수정 (기존 메서드 재정의)
# ─────────────────────────────────────────────
class MastodonClient
  def normalize_download_url(url)
    u = url.to_s.strip

    if u.include?("drive.google.com") || u.include?("drive.usercontent.google.com")
      file_id = nil
      if (m = u.match(%r{/file/d/([^/?#]+)}))
        file_id = m[1]
      elsif (m = u.match(/[?&]id=([^&#]+)/))
        file_id = m[1]
      end
      return "https://drive.google.com/uc?export=download&id=#{file_id}" if file_id
    end

    u
  end

  def upload_media_from_url(image_url, description: nil)
    download_url = normalize_download_url(image_url)

    data = download_binary(download_url)

    # 구글 드라이브가 HTML(확인 페이지)을 반환한 경우 대체 URL로 재시도
    if data.nil? || html_data?(data)
      if (m = download_url.match(/[?&]id=([^&#]+)/))
        alt = "https://drive.usercontent.google.com/download?id=#{m[1]}&export=download"
        data = download_binary(alt)
      end
    end

    if data.nil? || html_data?(data)
      puts "[MEDIA-URL 오류] 이미지 데이터를 받지 못했습니다: #{image_url}"
      return nil
    end

    ext = detect_ext(data)

    result = nil
    Tempfile.create(['item', ext]) do |file|
      file.binmode
      file.write(data)
      file.rewind
      result = upload_media(file.path, description: description)
    end
    result
  rescue => e
    puts "[MEDIA-URL 오류] #{e.class} - #{e.message}"
    nil
  end

  def download_binary(url)
    URI.open(url, 'User-Agent' => 'Mozilla/5.0') { |io| io.read }
  rescue => e
    puts "[다운로드 오류] #{e.class} - #{e.message} (#{url})"
    nil
  end

  def html_data?(data)
    head = data.to_s[0, 300].to_s
    head.include?('<html') || head.include?('<!DOCTYPE') || head.include?('<HTML')
  end

  def detect_ext(data)
    b = data.to_s.b
    return '.png'  if b[0, 8] == "\x89PNG\r\n\x1A\n".b
    return '.jpg'  if b[0, 3] == "\xFF\xD8\xFF".b
    return '.gif'  if b[0, 3] == 'GIF'
    return '.webp' if b[8, 4] == 'WEBP'
    '.png'
  end
end
