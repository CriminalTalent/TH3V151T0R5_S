  def add_house_credits(house_name, amount)
    rows = read(HOUSE_SHEET, 'A:B')
    normalized_house_name = house_name.to_s.strip
    rows[1..].to_a.each_with_index do |row, index|
      next unless row[0].to_s.strip == normalized_house_name
      current_score = (row[1] || 0).to_i
      new_score = current_score + amount.to_i
      success = write(
        HOUSE_SHEET,
        "B#{index + 2}",
        [[new_score]]
      )
      return false unless success
      
      # write 직후 재확인
      sleep 0.5
      verify_rows = read(HOUSE_SHEET, 'A:B')
      verify_rows[1..].to_a.each_with_index do |vrow, vidx|
        if vrow[0].to_s.strip == normalized_house_name
          verified_score = (vrow[1] || 0).to_i
          puts "[기부] #{house_name} 점수 확인: #{verified_score}"
          return verified_score
        end
      end
      
      return new_score
    end
    nil
  rescue => e
    puts "[add_house_credits 오류] #{e.message}"
    nil
  end
