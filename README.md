# 화이트 보드 홍보판

부스트가 많을수록 **더 크게** 보이는, 순백(#FFFFFF)의 공유 홍보판입니다.
회사·캐릭터·개인 프로젝트 홍보 이미지를 올리고, 클릭해서 부스트로 키웁니다.

- **라이브**: <https://nugj12-code.github.io/Promo-board/>
- **저장소**: <https://github.com/nugj12-code/Promo-board>
- **백엔드**: Supabase (Postgres + Realtime + Storage) — 실시간 공유
- **호스팅**: GitHub Pages (정적 파일 하나로 동작)

![화이트 보드 홍보판 미리보기](og.png)

---

## 1. 어떻게 동작하나요

### 부스트가 크기를 정합니다

| 부스트 횟수 | 단계 | 보드에서의 크기 |
| --- | --- | --- |
| 1–2 | 1 | 가장 작음 (1칸) |
| 3–5 | 2 | 1칸 |
| 6–10 | 3 | 1–2칸 |
| 11–20 | 4 | 2칸 |
| 21–40 | 5 | 2–3칸 |
| 41–80 | 6 | 3–3칸 |
| 81+ | 7 | 최대 (화면 폭에 따라 3–4칸) |

칸 수는 화면 폭에 따라 달라집니다(모바일 3칸 / 태블릿 4–5칸 / 데스크톱 6–7칸).
타일은 **가장 짧은 열부터 채우는 마소니(packed) 레이아웃**으로 배치되어 빈 공간이 생기지 않고,
부스트가 오르면 타일이 부드럽게 커지면서 주변이 다시 흘러갑니다.

### 부스트는 3단계입니다 (한 사람 · 한 카드 기준)

| 단계 | 횟수 | 방식 | 화면 문구 |
| --- | --- | --- | --- |
| 1 | 1–10회 | **무료** | `남은 무료 부스트 N/10` |
| 2 | 11–20회 | **광고 시청** (최대 10회, 5초) | `광고 보고 키우기 N/10` |
| 3 | 21회~ | **소액 결제** (₩500 / 1회) | `₩500/회` |

- 무료 10회를 다 쓰면 자동으로 광고 단계로, 광고 10회까지 다 쓰면 결제 단계로 넘어갑니다.
- 내가 쓴 부스트 횟수는 이 브라우저(`localStorage`)에 카드별로 기록됩니다. 기기를 바꾸면 무료 10회가 새로 시작합니다.

### 실시간 공유

Supabase `promo_items` 테이블의 변경(INSERT/UPDATE/DELETE)을 Realtime으로 구독합니다.
누군가 카드를 올리거나 부스트하면 접속 중인 모든 화면의 타일 크기가 즉시 바뀝니다.

---

## 2. 처음 한 번만 하면 되는 설정

### ① Supabase SQL 실행 (필수)

1. <https://supabase.com/dashboard> 에서 이 프로젝트를 엽니다 — `xvsutfyxxtkcxxbixgan`
2. 왼쪽 **SQL Editor** → **New query**
3. 이 저장소의 [`supabase_schema.sql`](supabase_schema.sql) **전체**를 붙여넣고 **Run**
   (여러 번 실행해도 안전합니다. 테이블·RPC·Realtime·Storage 버킷·정책이 한 번에 만들어집니다.)
4. 맨 아래 결과가 `promo_items_count | bucket_ok` 로 나오면 성공입니다.

> SQL을 실행하기 전에 사이트를 열면 상단에 **"DB 초기화 대기 중"** 안내가 뜨고 예시 카드로 미리 볼 수 있습니다.
> SQL을 실행하면 8초 안에 자동으로 실시간 공유 보드로 전환됩니다. (또는 안내의 **다시 확인** 버튼)

### ② Supabase 키 (이미 입력되어 있습니다)

`index.html` 맨 위 `CONFIG` 에 값이 들어 있습니다.

```js
const CONFIG = {
  SUPABASE_URL: 'https://xvsutfyxxtkcxxbixgan.supabase.co',
  SUPABASE_ANON_KEY: 'sb_publishable_...',   // 공개되어도 되는 anon(publishable) 키
  BUCKET: 'board-images',
  ...
};
```

다른 프로젝트로 옮길 때만 이 두 값을 바꾸면 됩니다.
값이 `YOUR_SUPABASE_URL` 같은 자리표시자면 앱이 자동으로 **로컬 체험 모드**로 열립니다.

> `anon` / `publishable` 키는 브라우저에 노출되는 공개 키입니다. 실제 접근 제어는 `supabase_schema.sql` 의 RLS 정책이 담당합니다.
> `service_role` 키는 절대 이 파일에 넣지 마세요.

### ③ GitHub Pages 켜기

1. <https://github.com/nugj12-code/Promo-board/settings/pages>
2. **Build and deployment → Source**: `Deploy from a branch`
3. **Branch**: `main` / 폴더 `/(root)` → **Save**
4. 1–2분 뒤 <https://nugj12-code.github.io/Promo-board/> 가 열립니다.

---

## 3. 광고 · 결제를 실제로 붙이는 곳

지금은 **미리보기(테스트)** 상태이고, 실제 광고/결제는 일어나지 않습니다.
아래 두 곳의 `TODO` 주석 자리에만 연결하면 됩니다.

### 리워드 광고 (2단계)

- `index.html` 의 `startAd()` / `finishAd()` 근처
- 광고 영역 DOM: `<div class="adbox" id="adBox">`
- `/* TODO: AdSense / Rewarded Ad SDK hook */`
- 광고 로드 실패·중간 이탈 시에는 `finishAd()` 를 호출하지 않도록 하고, 사용자에게 "광고를 끝까지 봐야 부스트가 올라가요"를 보여 주세요.

### 결제 (3단계)

- `index.html` 의 `#payBtn` 클릭 핸들러
- `/* TODO: Toss Payments / Stripe / Ko-fi hook */`
- `CONFIG.TOSS_CLIENT_KEY` 에 키를 넣으면 결제 모달의 "테스트 모드" 문구가 "결제 모듈 연결됨"으로 바뀝니다.
- **중요**: 결제 승인은 서버에서 검증한 뒤 부스트를 올려야 합니다.
  브라우저에서 결제 성공 콜백만 믿고 부스트를 올리면 조작될 수 있습니다.
  (권장 흐름: 결제 승인 → Supabase Edge Function 이 `service_role` 로 `boost_count` 증가)

---

## 4. 파일 구조

```
index.html            앱 전체 (HTML + CSS + JS, 의존성 없음 · supabase-js만 CDN)
supabase_schema.sql   DB · RPC · Realtime · Storage 한 번에 설정 (idempotent)
og.png                1200×630 미리보기 이미지 (OG 태그에도 사용)
.nojekyll             GitHub Pages 가 파일을 그대로 서빙하도록
README.md             이 문서
```

`index.html` 안의 큰 구획:

| 위치 | 내용 |
| --- | --- |
| `<style>` | 순백 모노크롬 디자인, 타일/모달/반응형 |
| `CONFIG` | Supabase URL·키, 부스트 정책, 광고/결제 훅 자리 |
| `LAYOUTS` | 화면 폭별 열 수와 부스트 단계별 칸 수 |
| `levelOf()` | 부스트 → 크기 단계(1~7) |
| `layout()` | 마소니 배치(가장 짧은 열부터) |
| `boostState()` | 무료/광고/결제 판정 |
| `applyBoost()` | 화면 반영 + `increment_boost` RPC 호출 |
| `connectCloud()` | Supabase 조회·구독, 테이블 없을 때 대기 처리 |

---

## 5. DB 구조

```sql
promo_items
  id          uuid primary key default gen_random_uuid()
  title       text        not null      -- 1~60자
  description text        not null default ''
  link_url    text                      -- http(s)만 허용
  image_url   text        not null
  boost_count integer     not null default 1   -- 1 이상
  created_at  timestamptz not null default now()
```

- **RLS**: 누구나 `select`, 누구나 `insert` (단, `boost_count = 1` 로만 생성 가능 → 부스트 수 조작 방지)
- **RPC**: `increment_boost(item_id uuid, amount integer default 1)` — `security definer`, `amount` 는 1만 허용, 반환값은 새 `boost_count`
- **Realtime**: `promo_items` 의 INSERT/UPDATE/DELETE 를 구독
- **Storage**: `board-images` 버킷 (공개 읽기, 누구나 업로드, 5MB, jpg/png/webp/gif)

---

## 6. 로컬에서 미리 보기

```bash
# 그냥 열기 (file:// 로도 동작합니다)
open index.html

# Supabase에 붙지 않고 이 브라우저에서만 (예시 카드 + localStorage)
open "index.html?local=1"

# 저장된 카드·부스트 기록 초기화
open "index.html?reset=1"
```

`?local=1` 은 디자인/동작을 확인할 때, `?reset=1` 은 보드를 처음 상태로 되돌릴 때 씁니다.

---

## 7. 운영 메모 (공개 서비스로 키울 때)

- **부스트 남용**: `increment_boost` 는 익명 호출이 가능합니다. 무료/광고/결제 단계는 브라우저에서 판단하므로,
  진짜로 막으려면 사용자 식별(Supabase Auth 또는 익명 세션)과 서버 측 한도(RPC 안에서 하루/카드별 횟수 제한, 또는 Edge Function)가 필요합니다.
- **이미지 검수**: 누구나 업로드할 수 있으므로 공개 게시 전 검수나 신고 기능을 두는 것을 권합니다.
  (Storage 정책에 `image/*` MIME 제한은 이미 걸려 있습니다.)
- **용량**: Supabase 무료 플랜은 Storage 1GB · DB 500MB 입니다. 업로드 이미지는 브라우저에서 최대 1600px 로 줄여 올립니다.
- **삭제**: 지금은 삭제 UI가 없습니다. 필요하면 `promo_items` 에 `delete` 정책과 카드 메뉴를 추가하세요.
  (익명 사용자끼리 남의 카드를 지우지 못하도록 소유자 개념이 먼저 필요합니다.)

---

## 8. 검증 기록

- `node --check` — 인라인 스크립트 문법 검사 통과
- Headless Chrome (iPhone 390×844 / 데스크톱 1440×900)
  - 배경 `rgb(255,255,255)` 순백, 타일 10개 렌더
  - 부스트가 많을수록 타일이 큼 (모바일 113 / 237 / 362px, 데스크톱 212 / 441 / 671px)
  - 상세 모달 → 무료 10회 → 광고 5초 → 광고 10회 → 결제(₩500 테스트) 전 단계 전환
  - 이미지 업로드(압축 포함) → 보드에 추가 → 상세에서 링크 노출
  - 콘솔 에러 0
- Supabase 미초기화 상태에서 `DB 초기화 대기 중` 안내 + 예시 카드 표시 확인
