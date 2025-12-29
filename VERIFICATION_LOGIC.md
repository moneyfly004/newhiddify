# 验证码功能逻辑验证文档

## 1. 注册流程验证码

### 前端流程
1. 用户在注册页面输入邮箱
2. 点击"发送验证码"按钮
3. 调用 `VerificationApi.sendVerificationCode(email: email, type: 'email')`
4. API: `POST /api/v1/auth/verification/send`
5. 请求参数: `{ "email": "xxx@xxx.com", "type": "email" }`
6. 发送成功后显示60秒倒计时
7. 用户输入验证码（6位数字，可选）
8. 提交注册时，如果输入了验证码，传递给后端

### 后端流程
1. `/api/v1/auth/verification/send` 接收请求
2. 检查注册功能是否启用
3. 生成6位数字验证码
4. 保存验证码到数据库，`purpose: "register"`，有效期5分钟
5. 发送验证码邮件
6. 注册时，检查配置 `email_verification_required`
7. 如果配置为 `true`，验证码必填；如果为 `false`，验证码可选
8. 验证验证码：检查是否存在、是否已使用、是否过期
9. 验证通过后标记验证码为已使用

### 验证点
- ✅ 前端发送验证码API调用正确
- ✅ 前端验证码输入框验证逻辑正确（6位数字）
- ✅ 前端倒计时功能正常
- ✅ 后端验证码生成和保存逻辑正确
- ✅ 后端验证码验证逻辑完整

## 2. 忘记密码流程

### 前端流程
1. 用户在忘记密码页面输入邮箱
2. 点击"发送验证码"按钮
3. 调用 `AuthRepository.forgotPassword(email)`
4. API: `POST /api/v1/auth/forgot-password`
5. 请求参数: `{ "email": "xxx@xxx.com" }`
6. 发送成功后显示提示，并跳转到重置密码页面
7. URL参数传递邮箱: `/auth/reset-password?email=xxx@xxx.com`

### 后端流程
1. `/api/v1/auth/forgot-password` 接收请求
2. 检查邮箱是否存在（为了安全，即使用户不存在也返回成功）
3. 生成6位数字验证码
4. 保存验证码到数据库，`purpose: "reset_password"`，有效期10分钟
5. 发送验证码邮件
6. 返回成功消息

### 验证点
- ✅ 前端忘记密码API调用正确
- ✅ 前端跳转逻辑正确，传递邮箱参数
- ✅ 后端自动生成和发送验证码逻辑正确
- ✅ 后端安全处理（即使用户不存在也返回成功）

## 3. 重置密码流程

### 前端流程
1. 用户在重置密码页面看到邮箱（从URL参数获取）
2. 输入验证码（6位数字，必填）
3. 输入新密码（至少8位，必填）
4. 确认新密码（必填，必须与新密码一致）
5. 点击"重置密码"按钮
6. 调用 `AuthRepository.resetPassword(ResetPasswordRequest(...))`
7. API: `POST /api/v1/auth/reset-password`
8. 请求参数: 
   ```json
   {
     "email": "xxx@xxx.com",
     "verification_code": "123456",
     "new_password": "newpassword123"
   }
   ```
9. 重置成功后跳转到登录页面

### 后端流程
1. `/api/v1/auth/reset-password` 接收请求
2. 验证请求参数格式
3. 验证密码强度（至少8位）
4. 检查用户是否存在
5. 验证验证码格式（6位数字）
6. 检查验证码是否存在（purpose: "reset_password"）
7. 检查验证码是否已使用
8. 验证验证码是否正确
9. 检查验证码是否过期
10. 标记验证码为已使用
11. 更新用户密码
12. 返回成功消息

### 验证点
- ✅ 前端重置密码API调用正确
- ✅ 前端字段名已修复：`verification_code` 和 `new_password`（之前错误地使用了 `code` 和 `password`）
- ✅ 前端邮箱参数获取逻辑正确
- ✅ 前端表单验证完整（验证码、密码、确认密码）
- ✅ 后端验证码验证逻辑完整
- ✅ 后端密码更新逻辑正确

## 4. 路由配置

### 路由定义
- ✅ `/auth/login` - 登录页面
- ✅ `/auth/register` - 注册页面
- ✅ `/auth/forgot-password` - 忘记密码页面
- ✅ `/auth/reset-password?email=xxx` - 重置密码页面

### 路由重定向逻辑
- ✅ 未登录用户访问受保护页面 → 重定向到登录页
- ✅ 已登录用户访问认证页面 → 重定向到主页
- ✅ 忘记密码和重置密码页面允许未登录用户访问

## 5. 潜在问题和改进建议

### 已修复的问题
1. ✅ **重置密码API字段名不匹配** - 已修复：`code` → `verification_code`，`password` → `new_password`
2. ✅ **重置密码页面邮箱参数获取** - 已优化：使用 `useEffect` 和 `addPostFrameCallback` 确保正确设置

### 建议改进
1. **注册验证码必填提示** - 如果后端配置要求验证码，前端应该提示用户必须填写
2. **验证码错误提示** - 可以显示更详细的错误信息（验证码错误、已过期、已使用等）
3. **验证码重发** - 倒计时结束后允许重新发送验证码

## 6. 测试检查清单

### 注册流程
- [ ] 发送验证码成功
- [ ] 验证码倒计时正常
- [ ] 输入正确验证码可以注册
- [ ] 输入错误验证码显示错误
- [ ] 验证码过期后显示错误
- [ ] 不输入验证码（如果后端配置允许）可以注册

### 忘记密码流程
- [ ] 输入邮箱发送验证码成功
- [ ] 跳转到重置密码页面，邮箱自动填充
- [ ] 输入错误邮箱也显示成功（安全考虑）

### 重置密码流程
- [ ] 输入正确验证码和新密码可以重置
- [ ] 输入错误验证码显示错误
- [ ] 验证码过期后显示错误
- [ ] 密码强度验证正常
- [ ] 重置成功后跳转到登录页面

## 7. API端点总结

| 功能 | 端点 | 方法 | 参数 |
|------|------|------|------|
| 发送注册验证码 | `/api/v1/auth/verification/send` | POST | `email`, `type: "email"` |
| 注册 | `/api/v1/auth/register` | POST | `username`, `email`, `password`, `verification_code?` |
| 忘记密码 | `/api/v1/auth/forgot-password` | POST | `email` |
| 重置密码 | `/api/v1/auth/reset-password` | POST | `email`, `verification_code`, `new_password` |

