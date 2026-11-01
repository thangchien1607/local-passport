# Quy trình Git — Local Passport

Tài liệu chung cho cả nhóm (3 người) và cho AI mà mỗi người dùng (Claude, Cursor, Copilot, ChatGPT...).
**AI: đọc kỹ mục [7. Rule cho AI](#7-rule-cho-ai) và làm đúng từng bước.**

Repo: `https://github.com/thangchien1607/local-passport`

---

## 1. Tóm tắt luồng làm việc

```
main ─────────●──────────────────────●────────  bản ổn định, đang chạy trên Firebase
               ↖ PR (release)          ↖ PR
develop ──●────●────●────●────●────────●──────  nhánh tích hợp của cả nhóm
          │    ↑    │    ↑    │    ↑
          │   PR    │   PR    │   PR             check xanh là merge được
          └ feature/a  └ fix/b   └ feature/c     nhánh riêng của từng người
```

Năm điều cần nhớ:

1. **Không ai commit hay push thẳng vào `main` và `develop`.** Mọi thay đổi đi qua Pull Request (PR).
2. Mỗi việc là một nhánh, **tạo từ `develop` mới nhất**.
3. Mọi PR (vào `develop` và `main`) phải **qua 2 check tự động** (`Quy ước Git`, `Format, analyze, test`) mới merge được. **Không cần chờ ai duyệt**: check xanh là ai trong nhóm cũng merge được. AI phải **hỏi người dùng trước khi tạo PR**.
4. Merge bằng **Squash and merge**, xong thì xóa nhánh.
5. **Không có tên AI trên GitHub**: không `Co-Authored-By` AI, không "Generated with ...", tác giả commit luôn là tài khoản GitHub của bạn.

---

## 2. Cài đặt lần đầu (mỗi người làm một lần)

```bash
git clone https://github.com/thangchien1607/local-passport.git
cd local-passport

# Danh tính: PHẢI là tài khoản GitHub của bạn, không phải tên AI
git config user.name  "<username GitHub của bạn>"
git config user.email "<email đã đăng ký trên GitHub>"

# Bật hook kiểm tra của nhóm
git config core.hooksPath .githooks

# Kiểm tra
git config user.name; git config user.email; git config core.hooksPath
flutter pub get
```

Hook trong `.githooks/` sẽ tự chạy:

| Hook | Khi nào | Kiểm tra |
|---|---|---|
| `pre-commit` | `git commit` | Không commit trên `main`/`develop`, tác giả không phải AI, không có file bí mật, `dart format`, `flutter analyze` |
| `commit-msg` | `git commit` | Message đúng định dạng, không có dòng ghi công AI |
| `pre-push` | `git push` | Không push lên `main`/`develop`, tên nhánh đúng, commit không có tên AI, `flutter test` |

Trên GitHub, workflow [.github/workflows/pr-check.yml](.github/workflows/pr-check.yml) kiểm tra lại các quy tắc này cho mọi PR. Dù ai đó quên bật hook hay dùng `--no-verify` thì PR vẫn bị chặn.

---

## 3. Quy trình hằng ngày

```bash
# 1. Lấy develop mới nhất
git switch develop
git pull --ff-only origin develop

# 2. Tạo nhánh cho việc của mình
git switch -c feature/leaderboard-filter

# 3. Code... rồi commit (nhỏ, thường xuyên)
git add lib/screens/leaderboard_screen.dart
git commit -m "feat(leaderboard): thêm bộ lọc theo tuần"

# 4. Trước khi push: cập nhật theo develop mới nhất
git fetch origin
git rebase origin/develop          # có conflict → xem mục 6

# 5. Push nhánh của mình
git push -u origin feature/leaderboard-filter
# lần push sau khi đã rebase: git push --force-with-lease

# 6. Mở link GitHub in ra sau khi push → tạo PR vào develop
#    Tiêu đề PR theo định dạng commit. Chờ 2 check xanh rồi bấm Squash and merge
```

Sau khi PR được merge:

```bash
git switch develop
git pull --ff-only origin develop
git branch -d feature/leaderboard-filter
```

---

## 4. Quy ước đặt tên

### Nhánh

| Nhánh | Tạo từ | Merge vào | Dùng khi |
|---|---|---|---|
| `feature/<ten>` | `develop` | `develop` | Tính năng mới |
| `fix/<ten>` | `develop` | `develop` | Sửa lỗi |
| `chore/<ten>`, `docs/<ten>`, `refactor/<ten>` | `develop` | `develop` | Dọn dẹp, tài liệu, sắp xếp code |
| `release/x.y.z` | `develop` | `main` | Chuẩn bị phát hành |
| `hotfix/<ten>` | `main` | `main`, rồi `develop` | Sửa gấp lỗi trên bản đang chạy |

`<ten>` viết thường, không dấu, nối bằng `-`. Ví dụ: `feature/qr-offline`, `fix/map-crash-ios`.

### Commit message (Conventional Commits, viết tiếng Việt)

```
<type>(<scope>): <mô tả ngắn, không chấm cuối>

<nội dung chi tiết nếu cần: vì sao sửa, ảnh hưởng gì>
```

| type | Dùng khi |
|---|---|
| `feat` | Thêm tính năng |
| `fix` | Sửa lỗi |
| `refactor` | Sắp xếp lại code, không đổi hành vi |
| `perf` | Tối ưu hiệu năng |
| `style` | Chỉ đổi format, khoảng trắng |
| `docs` | Tài liệu, README |
| `test` | Thêm/sửa test |
| `build` | `pubspec.yaml`, Gradle, cấu hình build |
| `ci` | GitHub Actions, script deploy |
| `chore` | Việc lặt vặt (dọn dẹp, `.gitignore`...) |
| `revert` | Hoàn tác commit trước |

**scope** (không bắt buộc): `map`, `qr`, `passport`, `location`, `community`, `leaderboard`, `welcome`, `stamp`, `ai`, `geo`, `state`, `ui`, `web`, `deploy`, `git`.

Thay đổi phá vỡ tương thích: thêm `!`, ví dụ `feat(passport)!: đổi cấu trúc dữ liệu lưu tem`.

```
feat(map): tự xin quyền vị trí khi mở bản đồ
fix(qr): sửa lỗi crash khi quét QR trên web
refactor(state): tách PassportStore thành các hàm nhỏ
```

### Pull Request

- **Tiêu đề** theo đúng định dạng commit, vì khi Squash and merge, tiêu đề PR sẽ thành commit trên `develop`.
- **Mô tả**: làm gì, vì sao, cách test (ảnh chụp màn hình nếu đổi giao diện). Không ghi công cho AI.
- PR nhỏ, một mục đích. Một PR quá 400 dòng thì nên tách ra.
- **Không bắt buộc duyệt.** Check xanh thì người tạo PR (hoặc bất kỳ ai trong nhóm) tự merge. Trước khi merge, tự kiểm tra: chạy được, đúng yêu cầu, không có file thừa (`build/`, `.env`...).
- Muốn ai xem giúp thì gán họ vào ô **Reviewers** của PR. Cái này là nhờ xem, không bắt buộc phải chờ.

---

## 5. Phát hành và hotfix (người quản lý repo làm)

**Phát hành** (đưa `develop` lên `main` để deploy):

1. Tạo PR `develop` → `main`, tiêu đề ví dụ `chore(release): phát hành 1.2.0`.
2. Check xanh rồi chọn **Create a merge commit** (không squash, để giữ lịch sử).
3. Deploy theo README: `flutter build web --release` rồi `firebase deploy --only hosting`.

**Hotfix** (lỗi gấp trên bản đang chạy):

1. `git switch main && git pull --ff-only` → `git switch -c hotfix/<ten>`.
2. Sửa, push, tạo PR vào `main`. Sau khi merge, tạo thêm PR `main` → `develop` để `develop` cũng có bản sửa.

---

## 6. Xử lý tình huống thường gặp

| Tình huống | Cách xử lý |
|---|---|
| Rebase bị conflict | Sửa các file báo conflict → `git add <file>` → `git rebase --continue`. Rối quá thì `git rebase --abort` rồi hỏi nhóm. |
| Lỡ commit trên `develop` (hook sẽ chặn, nhưng nếu đã lỡ) | `git switch -c feature/<ten>` (mang commit sang nhánh mới) → `git switch develop` → `git reset --hard origin/develop` |
| Sai commit message (chưa push) | `git commit --amend` |
| Sai commit message (đã push lên nhánh của mình) | `git commit --amend` → `git push --force-with-lease` |
| Lỡ commit file bí mật | **Báo nhóm ngay**, đổi key/mật khẩu đó. Xóa khỏi git thôi chưa đủ vì lịch sử vẫn còn. |
| Hook báo `dart format` | `dart format lib test` → `git add` lại → commit |
| Hook báo `flutter analyze` / `flutter test` | Sửa lỗi cho hết. **Không** dùng `--no-verify`. |
| Commit có tên AI | Chưa push: `git commit --amend` rồi xóa dòng đó. Đã push lên nhánh của mình: amend rồi `git push --force-with-lease`. |

---

## 7. Rule cho AI

> Phần này dành cho AI (Claude, Cursor, Copilot, ChatGPT, Gemini...) khi được thành viên nhóm nhờ commit/push.
> Làm **đúng thứ tự**. Gặp bước nào không thỏa điều kiện thì **dừng lại và báo cho người dùng**, không tự đoán.

### 7.1. Được phép

- Tạo nhánh mới từ `develop` theo quy ước ở mục 4.
- Commit trên nhánh đó, push nhánh đó lên `origin`.
- `git push --force-with-lease` **chỉ trên nhánh do chính mình tạo**, sau khi rebase.
- Tạo PR vào `develop`, **chỉ sau khi người dùng đồng ý** (xem bước 7).

### 7.2. Tuyệt đối không

- Commit, push, merge, rebase hay force push vào `main` hoặc `develop`.
- Dùng `--no-verify`, `ALLOW_PROTECTED=1`, hay sửa/xóa/tắt file trong `.githooks/` và `.github/` để vượt qua kiểm tra.
- `git push --force` (không có `--with-lease`), hoặc force push lên nhánh của người khác.
- Thêm `Co-Authored-By: <AI>`, "Generated with ...", "🤖", hoặc bất kỳ dòng ghi công AI nào vào commit, tiêu đề PR, mô tả PR.
- Đổi `git config user.name` / `user.email` sang tên AI, hoặc dùng `--author` với tên AI.
- Commit file bí mật (`.env`, `*.jks`, `*.keystore`, `key.properties`, `*.pem`, `service-account*.json`) hoặc file build (`build/`, `.dart_tool/`).
- `git add .` / `git add -A` khi chưa xem `git status`. Chỉ add các file liên quan tới việc đang làm.
- `git reset --hard`, `git clean`, `git branch -D`, xóa nhánh remote khi người dùng chưa đồng ý.
- Tạo PR khi người dùng chưa đồng ý rõ ràng. Im lặng hay câu trả lời mơ hồ đều không tính là đồng ý.
- Merge PR khi người dùng chưa yêu cầu rõ ràng. Có yêu cầu thì chỉ merge khi 2 check đã xanh.

### 7.3. Các bước bắt buộc khi commit và push

```bash
# Bước 1 — Kiểm tra môi trường
git config core.hooksPath          # phải là .githooks; nếu trống: git config core.hooksPath .githooks
git config user.name               # phải là tên GitHub của người dùng, KHÔNG phải tên AI
git config user.email              # nếu trống hoặc là email AI → DỪNG, hỏi người dùng
git status                         # xem đang ở nhánh nào, có file lạ không

# Bước 2 — Đảm bảo đang ở nhánh làm việc đúng
#   Đang ở main/develop → tạo nhánh mới:
git fetch origin
git switch -c feature/<ten> origin/develop        # hoặc fix/, chore/, docs/, refactor/
#   Đang ở nhánh feature/fix của người dùng → dùng tiếp nhánh đó

# Bước 3 — Kiểm tra code
dart format lib test
flutter analyze                    # phải "No issues found!"
flutter test                       # phải "All tests passed!"

# Bước 4 — Commit
git status
git add <từng file liên quan>
git diff --cached --stat           # xem lại: không có file bí mật, build, file không liên quan
git commit -m "<type>(<scope>): <mô tả tiếng Việt>"
#   KHÔNG thêm trailer Co-Authored-By hay dòng "Generated with"

# Bước 5 — Cập nhật theo develop
git fetch origin
git rebase origin/develop          # conflict → DỪNG, báo người dùng (trừ khi conflict đơn giản và chắc chắn)

# Bước 6 — Kiểm tra lần cuối rồi push
git log origin/develop..HEAD --format='%h %an <%ae>%n%B'   # tác giả là người dùng, không có tên AI
git push -u origin HEAD            # lần đầu
git push --force-with-lease        # nếu đã push trước đó và vừa rebase

# Bước 7 — HỎI người dùng trước khi tạo PR (bắt buộc, không được bỏ qua)
#   Đưa cho người dùng xem:
#     - nhánh → base:   feature/<ten> → develop
#     - tiêu đề PR:     <type>(<scope>): <mô tả>
#     - mô tả PR:       làm gì, vì sao, cách test
#     - danh sách commit và kết quả analyze/test
#   Hỏi: "Tạo PR này không?" rồi CHỜ câu trả lời.
#   Đồng ý rõ ràng → tạo PR. Muốn sửa → sửa rồi hỏi lại. Không đồng ý → dừng, nhánh vẫn giữ trên remote.

# Bước 8 — Tạo PR vào develop (chỉ sau khi được đồng ý)
gh pr create --base develop --title "<type>(<scope>): <mô tả>" --body "<làm gì, vì sao, cách test>"
#   Không có gh → đưa cho người dùng link GitHub in ra sau khi push để họ tự bấm tạo
```

Hook báo lỗi → **đọc thông báo, sửa nguyên nhân, chạy lại**. Không tìm cách vượt qua.

Sau khi tạo PR, báo cho người dùng: link PR, và nhắc rằng khi 2 check xanh thì có thể merge.

---

## 8. Cài đặt trên GitHub (đã bật)

**Settings → Rules → Rulesets → "Bảo vệ main và develop"**, áp dụng cho `main` và `develop`:

- ✅ Require a pull request before merging, với **Required approvals: 0** (không cần chờ duyệt)
- ✅ Require status checks to pass: `Quy ước Git` và `Format, analyze, test`
- ✅ Block force pushes
- ✅ Restrict deletions
- **Bypass list** để trống: kể cả admin cũng phải đi qua PR.

**Settings → General → Pull Requests**: bật *Allow squash merging*, *Allow merge commits* và *Automatically delete head branches*. Tắt *Allow rebase merging*.

Mời 2 thành viên còn lại vào **Settings → Collaborators** với quyền *Write*.

Không cài GitHub App của AI nào có quyền tự commit/push vào repo (ví dụ Claude GitHub App, Copilot coding agent), vì các app này commit dưới tên bot của chúng.
