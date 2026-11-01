# Hướng dẫn cho AI agent

App Flutter (Web/Android/iOS), deploy bản web lên Firebase Hosting. Xem README.md để chạy và deploy.

## Git

Trước mọi thao tác git (commit, push, tạo PR), đọc và làm đúng **git.md**, mục "7. Rule cho AI". Bắt buộc:

- Chỉ làm việc trên nhánh `feature/`, `fix/`, `chore/`, `docs/`, `refactor/` tạo từ `develop`. Không commit/push vào `main` hay `develop`.
- Commit message tiếng Việt, dạng `<type>(<scope>): <mô tả>`.
- Không ghi công cho AI ở bất cứ đâu: không `Co-Authored-By: <AI>`, không "Generated with ...", không "🤖" trong commit, tiêu đề PR, mô tả PR. Tác giả commit luôn là tài khoản GitHub của người dùng.
- Không dùng `--no-verify`, `ALLOW_PROTECTED=1`, `git push --force` (chỉ `--force-with-lease` trên nhánh của mình). Không sửa `.githooks/` hay `.github/` để vượt qua kiểm tra.
- Trước khi commit: `dart format lib test`, `flutter analyze`, `flutter test` đều phải sạch.
- **Phải hỏi người dùng trước khi tạo PR**: đưa ra nhánh, base, tiêu đề, mô tả, danh sách commit, rồi chờ họ đồng ý rõ ràng (git.md mục 7.3, bước 7).
- PR không cần duyệt, 2 check xanh là merge được. AI chỉ merge khi người dùng yêu cầu rõ ràng và check đã xanh. Không xóa nhánh của người khác.
