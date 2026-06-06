# Shop Bot - README
마스토돈에서 명령어 기반으로 작동하는 마법 상점 RPG 봇
Google Sheets를 데이터 저장소로 활용하며, 아이템 구매·양도·사용, 갈레온 정산, 타로, 베팅 등 다양한 기능을 제공합니다.

## 주요 기능
| 명령어 형태 | 기능 설명 |
|-------------|-----------|
| `[구매/아이템명]` | 상점에서 아이템 구매 (갈레온 차감) |
| `[양도/아이템명/@상대ID]` | 아이템을 다른 사용자에게 양도 |
| `[양도/갈레온/@상대ID]` | 갈레온을 상대에게 송금 |
| `[사용/아이템명]` | 아이템 사용 (효과 적용 및 제거) |
| `[주머니]` | 소지 아이템과 갈레온 확인 |
| `[타로]` | 타로카드 뽑기 (78장 풀덱, 제한 없음) |
| `[베팅/갈레온]` | 무작위 배당률로 베팅 (-5x ~ +5x) |
| `[nD]` | 1~100면 주사위 (예: [6D], [20D], [100D]) |
| `[동전]` | 앞/뒤 동전 던지기 결과 |
| `[YN]` | YES/NO/Maybe/Why not? 랜덤 답변 |

**제한사항:**
- 부채(갈레온이 음수)일 경우 구매, 양도, 베팅 금지
- 아이템 양도 및 사용만 허용됩니다

## 설치 및 실행

### 1. 의존성 설치
```bash
bundle install
```

### 2. .env 파일 설정
```env
MASTODON_BASE_URL=https://eclyria.pics
MASTODON_TOKEN=당신의_마스토돈_토큰
GOOGLE_SHEET_ID=스프레드시트_ID
```
※ .env는 루트에 위치하며, Git에 커밋하지 마세요.

### 3. Google 서비스 계정 설정
1. Google Cloud Console에서 서비스 계정 생성
2. JSON 키를 다운로드 → `credentials.json`로 저장
3. Google Sheets의 공유 설정에서 서비스 계정 이메일을 "편집자"로 추가

### 4. 실행
```bash
ruby main.rb
```
봇이 멘션을 실시간으로 수신하고 응답합니다.

## 스프레드시트 구조

### 시트 탭
- **사용자**: 학생별 갈레온, 아이템, 부채
- **아이템**: 이름, 설명, 가격, 판매 여부
- **타로로그**: 타로카드 이름 및 의미

## 코드 구조
```
hogwarts_shop_bot/
├── main.rb                # 봇 실행
├── .env                   # 환경변수
├── credentials.json       # Google API 키
├── sheet_manager.rb       # 시트 연동 모듈
├── mastodon_client.rb     # 마스토돈 API 클라이언트
├── command_parser.rb      # 멘션 파서 및 분기 처리
└── commands/              # 명령어별 핸들러
    ├── buy_command.rb
    ├── pouch_command.rb
    ├── use_item_command.rb
    ├── transfer_item_command.rb
    ├── transfer_galleons_command.rb
    ├── tarot_command.rb
    ├── bet_command.rb
    ├── coin_command.rb
    ├── dice_command.rb
    └── yn_command.rb
```

## 예시

### 마스토돈에서 멘션을 통해 봇에게 입력:
```
@[bot_id] [구매/마법의 쿠키]
```

### 봇 응답:
```
마법의 쿠키을(를) 10갈레온에 구매했단다. 남은 갈레온은 43갈레온 이란다.
```

### 주사위 사용 예시:
```
@[bot_id] [6D]     → "6면 주사위: 4"
@[bot_id] [20D]    → "20면 주사위: 15"  
@[bot_id] [100D]   → "100면 주사위: 73"
```

## 개발 도구
- Ruby 3.0
- Mastodon API (mastodon-api gem)
- Google Sheets API (google-apis-sheets_v4)
- .env 기반 설정 관리 (dotenv)

## 추가 설정 추천

### .gitignore에 다음 포함:
```gitignore
.env
credentials.json
config.json
```
