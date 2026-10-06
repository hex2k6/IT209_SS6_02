# Bài 2: Cấu hình phân quyền nhóm và sudoers bằng visudo

## Mục tiêu và môi trường

Tạo nhóm `devops-admin`, tạo user non-root `deployer`, cấp quyền không cần mật khẩu cho các thao tác start, stop, restart và status của `systemctl`. Thực hành trên máy Ubuntu 24.04 tạm thời của GitHub Actions; không thay đổi tài khoản hoặc đặc quyền trên máy Windows cá nhân.

## 1. Tạo nhóm và tài khoản

```bash
sudo groupadd devops-admin
sudo adduser --disabled-password --gecos '' deployer
sudo usermod -aG devops-admin deployer
id deployer
```

`--disabled-password` tạo tài khoản không có mật khẩu đăng nhập để dùng trong bài tự động hóa. Không thêm `deployer` vào nhóm `sudo`. `usermod -aG` bổ sung nhóm phụ, giữ các nhóm cũ. Sau đó mở phiên đăng nhập mới để nhận nhóm mới.

## 2. Cấu hình bằng visudo

Trong phiên tương tác, quản trị viên chạy:

```bash
sudo visudo -f /etc/sudoers.d/devops-admin
```

Đây là file được `/etc/sudoers` nạp thông qua thư mục `sudoers.d`. Tách quy tắc thành file riêng giúp quản lý dễ hơn. Nội dung chính xác:

```sudoers
%devops-admin ALL=(root) NOPASSWD: /usr/bin/systemctl ^start [a-zA-Z0-9_][a-zA-Z0-9_.@-]*$, /usr/bin/systemctl ^stop [a-zA-Z0-9_][a-zA-Z0-9_.@-]*$, /usr/bin/systemctl ^restart [a-zA-Z0-9_][a-zA-Z0-9_.@-]*$, /usr/bin/systemctl ^--no-pager status [a-zA-Z0-9_][a-zA-Z0-9_.@-]*$
```

- `%devops-admin`: áp dụng cho mọi tài khoản thuộc nhóm.
- `ALL`: quy tắc áp dụng trên mọi host mà file này được cài đặt.
- `(root)`: chỉ cho chạy các lệnh được liệt kê với user đích root.
- `NOPASSWD`: không hỏi mật khẩu cho các lệnh khớp quy tắc, không cấp quyền cho mọi lệnh.
- Các biểu thức từ `^` đến `$` khớp toàn bộ tham số: một thao tác và một tên dịch vụ thông thường, không nhận tham số bổ sung. Hỗ trợ tên như `cron`, `cron.service`, `example@instance.service`.

Bài dùng regex thay cho wildcard rộng trong gợi ý để giới hạn tham số, và bắt buộc `--no-pager` khi xem status. Cú pháp này cần sudo từ 1.9.10 trở lên, theo [tài liệu chính thức sudoers](https://www.sudo.ws/docs/man/1.9.14/sudoers.man.pdf). Bốn thao tác yêu cầu vẫn được cấp quyền; lệnh xem trạng thái là `sudo systemctl --no-pager status cron`.

Trong CI không có người thao tác trình soạn thảo, [practice.sh](practice.sh) tạo một editor helper do root sở hữu để đưa nội dung [devops-admin.sudoers](devops-admin.sudoers) vào file tạm của `visudo`, sau đó `visudo` kiểm tra và lưu. Đây là cách chạy không tương tác; không mô tả thành thao tác gõ trong editor. Các lệnh đã dùng:

```bash
sudo install -m 600 devops-admin.sudoers /root/ex2-rule
printf '#!/bin/sh\nfor target do :; done\ncat /root/ex2-rule > "$target"\n' | sudo tee /root/ex2-editor >/dev/null
sudo chmod 700 /root/ex2-editor
sudo env EDITOR=/root/ex2-editor VISUAL=/root/ex2-editor /usr/sbin/visudo -f /etc/sudoers.d/devops-admin
sudo chmod 440 /etc/sudoers.d/devops-admin
sudo chmod 440 /etc/sudoers.d/runner
sudo /usr/sbin/visudo -c
```

Dòng chỉnh quyền `/etc/sudoers.d/runner` xử lý riêng file có sẵn trong image GitHub Actions, để kiểm tra toàn bộ cấu hình bằng `visudo -c` đạt yêu cầu quyền `0440`. Không cần dòng này trên máy không có file đó. Nội dung quyền của runner không thay đổi và deployer không thuộc nhóm runner.

## 3. Đăng nhập deployer và kiểm tra

Quản trị viên dùng `sudo su - deployer` vì user deployer không đặt mật khẩu. Dấu `-` tạo phiên login mới. Nếu đang là root có thể dùng trực tiếp `su - deployer` như đề. Script dùng `sudo su - deployer -c 'bash -s'` để chạy cùng các kiểm tra trong phiên deployer:

```bash
whoami
id
sudo -l
sudo -k
sudo -n systemctl restart cron
sudo -n systemctl --no-pager status cron
systemctl is-active cron
```

`sudo -k` xóa thông tin xác thực đã nhớ; `-n` cấm hỏi mật khẩu. Vì thế restart thành công sau hai tùy chọn này chứng minh quy tắc NOPASSWD hoạt động, không phụ thuộc mật khẩu được lưu trước đó. Người dùng cũng có thể chạy `sudo systemctl restart cron` đúng như đề.

### Kết quả thực tế

[Lần chạy thành công trên GitHub Actions](https://github.com/hex2k6/IT209_SS6_02/actions/runs/37485260355), commit thực hành `0d6169c`, sudo phiên bản `1.9.15p5`. `visudo -c` kiểm tra thành công. Nhật ký đầy đủ của bước thực hành nằm trong [command-output.txt](command-output.txt), đã bỏ tiền tố timestamp của GitHub, giữ nguyên nội dung đầu ra. Mốc giờ bên trong đầu ra systemctl là UTC của máy chạy.

Dưới đây là kết quả lấy từ phiên login `deployer`:

```text
deployer
uid=1003(deployer) gid=1003(deployer) groups=1003(deployer),100(users),1002(devops-admin)
$ sudo -l
Matching Defaults entries for deployer on runnervmmprz5:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin, use_pty

User deployer may run the following commands on runnervmmprz5:
    (root) NOPASSWD: /usr/bin/systemctl ^start [a-zA-Z0-9_][a-zA-Z0-9_.@-]*$, /usr/bin/systemctl ^stop [a-zA-Z0-9_][a-zA-Z0-9_.@-]*$, /usr/bin/systemctl ^restart [a-zA-Z0-9_][a-zA-Z0-9_.@-]*$, /usr/bin/systemctl ^--no-pager status [a-zA-Z0-9_][a-zA-Z0-9_.@-]*$
$ sudo -n systemctl restart cron
restart exit code: 0 (no password prompt)
$ sudo -n systemctl --no-pager status cron
* cron.service - Regular background program processing daemon
     Loaded: loaded (/usr/lib/systemd/system/cron.service; enabled; preset: enabled)
     Active: active (running) since Tue 2026-10-06 15:13:37 UTC; 8ms ago
       Docs: man:cron(8)
   Main PID: 2318 (cron)
      Tasks: 1 (limit: 19137)
     Memory: 472.0K (peak: 472.0K)
        CPU: 1ms
     CGroup: /system.slice/cron.service
             `-2318 /usr/sbin/cron -f -P

Oct 06 15:13:37 runnervmmprz5 systemd[1]: Started cron.service - Regular background program processing daemon.
Oct 06 15:13:37 runnervmmprz5 cron[2318]: (CRON) INFO (pidfile fd = 3)
Oct 06 15:13:37 runnervmmprz5 cron[2318]: (CRON) INFO (Skipping @reboot jobs -- not system startup)
$ systemctl is-active cron
active
Checking disallowed commands (must fail):
sudo: a password is required
sudo: a password is required
sudo: a password is required
PASS: NOPASSWD restart works; unrelated commands and extra options denied.
```

`sudo -l` hiển thị quyền hiệu lực của user, không nhất thiết in lại tên nhóm `%devops-admin`; dòng cấu hình ở mục 2 và kết quả `id` xác nhận quyền đến từ nhóm này.

## 4. Phạm vi quyền

Các lệnh ngoài danh sách như `sudo id`, `sudo systemctl daemon-reload` và restart kèm tùy chọn thêm phải bị từ chối. Quy tắc cho phép quản lý nhiều dịch vụ nên vẫn có ảnh hưởng vận hành lớn. Trên máy thật nên giới hạn thêm danh sách dịch vụ cần thiết và bảo đảm deployer không sửa được unit file, chương trình hay cấu hình thực thi với quyền root của các dịch vụ đó. Không cấp `NOPASSWD: ALL`.

Máy Actions là môi trường tạm thời; cấu hình, script và kết quả được lưu ở repository để nộp và tái hiện bài.
