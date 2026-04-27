# 🏊 SwimSignup 部署指南 (v4)

为开发者 **Zoe Stella** 准备的部署手册。预计耗时 **30–45 分钟** 完成测试版上线。

## 总体架构

```
家长手机/电脑 ─┐
              ├──>  GitHub Pages (托管 HTML)  ──>  Supabase
教练手机/电脑 ─┘                                   ├ 数据库
                                                    ├ 教练登录 (Auth)
                                                    └ Realtime 实时推送
```

**总成本: $0/月** (除非月活超过 5 万人)

## 时区: 全部锁定到美东时间 `America/New_York`

不管谁打开网页（家长在中国出差、教练手机时区错了），所有"周三 10:00"显示的都是 **RTP 当地时间**，自动处理夏令时切换。

---

## 第 1 步：注册 Supabase 并创建项目

1. 打开 [https://supabase.com](https://supabase.com)，用 GitHub 账号注册（最快）
2. 登录后点 **New Project**
3. 填写：
   - **Name**：`swim-signup`
   - **Database Password**：设强密码并**记下来**（用密码管理器存好）
   - **Region**：选 **East US (North Virginia)** — 离 RTP 最近，延迟最低
   - **Pricing Plan**：Free
4. 点 **Create new project**，等约 2 分钟初始化

---

## 第 2 步：拿到项目 URL 和 API Key

项目就绪后：

1. 左侧导航栏 → **Project Settings** (齿轮图标) → **API Keys**
2. 复制两个值：
   - **Project URL**：形如 `https://abcdefghijk.supabase.co`
   - **API Keys** 标签 → **Publishable key** (`sb_publishable_...`)
     - 看不到 publishable key 就到 **Legacy API Keys** 复制 **anon public** 那一栏（以 `eyJ...` 开头的长串）

⚠️ **千万不要复制 service_role / secret 那个** — 那是后端用的，前端拿到等于把整个数据库交给所有人。

### 关于 "API key 暴露"

放在浏览器里的是 **publishable key (匿名 key)**，这是 Supabase 设计上就让你公开的。它的作用只是"识别这是哪个项目"。**真正的安全防线是数据库的 RLS 策略**（第 3 步建表脚本里那一堆 `create policy`）。即使有人复制了你的 key，他能做的事和家长打开网页能做的完全一样。

**没有任何 API 调用费用** — 免费套餐**无限 API 请求**，只有数据库容量(500MB)、流量(5GB/月)、月活(5万)有限制，对你的用例都用不到 1%。

---

## 第 3 步：建表 + 启用 Realtime

1. 左侧导航栏 → **SQL Editor**
2. 点 **+ New query**
3. **打开 swim-signup.html，搜索 `SQL_SCRIPT`，把那一整段 SQL 复制出来**（也可以直接打开网页，配置警告页里有完整可复制的代码框）
4. 粘贴到 SQL Editor，点右下角 **Run**
5. 应该看到 "Success. No rows returned"

这一步会创建 5 张表：
- `app_admins` — 超级管理员名单（你和未来可能加的开发者）
- `releases` — 教练发布的可预约时段
- `bookings` — 单次预约
- `recurring_requests` — 家长的循环申请
- `recurring_approved` — 教练已批准的循环

并且会启用：
- **RLS** (行级安全) — admin 全权 / 教练能发布和批准 / 家长能报名和取消
- **Realtime** (实时推送) — 教练发布时段，家长打开的所有页面立刻更新，不需要刷新

---

## 第 4 步：创建 admin 账号（你 = Zoe Stella）

### 4.1 创建 Supabase 用户

1. 左侧导航栏 → **Authentication** → **Users**
2. 点右上角 **Add user** → **Create new user**
3. 填：
   - **Email**: 你的常用邮箱
   - **Password**: 设强密码
   - 勾选 **Auto Confirm User** ⚠️ 这步必须勾
4. 点 Create
5. **复制刚创建用户的 User UID** （在用户列表里点你的邮箱，里面有个长长的 UUID）

### 4.2 把你设为 admin

回到 **SQL Editor**，新建一个 query，执行：

```sql
insert into app_admins (user_id, name)
values ('你刚复制的UUID', 'Zoe Stella');
```

例如：
```sql
insert into app_admins (user_id, name)
values ('a1b2c3d4-5678-90ab-cdef-1234567890ab', 'Zoe Stella');
```

如果之后还想加 admin（比如另一个开发者），重复 4.1 + 4.2 即可。

### 4.3 关掉公开注册（推荐）

防止陌生人在你的 Supabase 注册账号：
- **Authentication** → **Providers** → **Email** → 关掉 **Enable Sign-ups** → Save

---

## 第 5 步：把 URL 和 Key 填进 HTML

1. 用 VS Code 之类编辑器打开 `swim-signup.html`
2. 文件最上面 `<script>` 区里有这两行：
   ```javascript
   const SUPABASE_URL = 'YOUR_SUPABASE_URL_HERE';
   const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY_HERE';
   ```
3. 把第 2 步复制的两个值替换进去（保留两边引号）
4. 保存

### 本地测试

直接双击 HTML 文件，浏览器打开。试一下：
1. 点右上角 **教练** → 用你的邮箱密码登录 → 应该看到右上角出现紫色 `ADMIN` 标识，并且多了一个紫色 `⚡ Admin` 按钮
2. 点 `⚡ Admin` → 进入超级管理后台，看到 6 个标签页
3. 切回 **教练** → 发布几个时段
4. 在另一个**无痕窗口**打开同一个 HTML（模拟家长） → 立刻看到那些时段（**不需要刷新** —— 这就是 Realtime）
5. 家长报名一个 → 教练那边马上看到（也不用刷新）

---

## 第 6 步：上传到 GitHub 并启用 Pages

### 创建仓库

1. [https://github.com/new](https://github.com/new)
2. **Repository name**: `swim-signup`
3. **Public** (GitHub Pages 免费版要求公开)
4. 勾上 **Add a README file**
5. **Create repository**

### 上传 HTML

⚠️ **改名后再上传**：把 `swim-signup.html` 改名为 `index.html`（GitHub Pages 默认找这个名字）。

仓库页面 → **Add file** → **Upload files** → 拖入 `index.html` → Commit。

### 启用 Pages

1. 仓库 → **Settings** → 左边栏 **Pages**
2. **Source**: `Deploy from a branch`
3. **Branch**: `main`, `/ (root)` → **Save**
4. 等 1-2 分钟，顶部出现：
   > Your site is live at `https://你的用户名.github.io/swim-signup/`

公测链接发给你认识的几位家长就行。

---

## ⚡ Admin 后台用法（你的开发者权限）

登录后右上角紫色 `⚡ Admin` 按钮进入。**家长完全看不到这个按钮**，普通教练（如果将来扩展多教练）也看不到。

### 7 个标签页

| 标签 | 作用 |
|---|---|
| **概览** | 系统统计、所有家长邮箱→孩子映射 |
| **所有预约** | 完整 bookings 表，可强制取消/恢复/删除任何记录 |
| **所有循环** | 申请 + 已批准循环全表，可强制操作 |
| **发布时段** | 按周分组列出所有发布，可强制撤销 |
| **账号管理** | 当前 admin 列表，扩展时参考 |
| **原始 JSON** | 一键看所有表数据 + 下载完整备份 |
| **危险区** | 清空测试数据、从备份导入 |

### 你能做但教练不能做的事

- 改任何家长的预约（强制取消/恢复）
- 删除任何记录（物理删除，普通教练只能"标记取消"）
- 看所有原始数据（普通教练只看课表展示）
- 备份和恢复
- 清空所有数据（用于重置测试环境）

### 升级维护流程

将来想加功能或修 bug：
1. 本地改 HTML
2. 推送新 `index.html` 到 GitHub（**Add file → Upload files** 覆盖）
3. GitHub Pages 1-2 分钟自动更新
4. 数据库结构如果要改，写一段 migration SQL，在 Supabase **SQL Editor** 执行
5. 改完先在无痕窗口测试一遍再正式发布

---

## 📊 监控用量

Supabase Dashboard → **Settings** → **Usage** 能看到：
- Database size（500MB 限额）
- Egress（5GB/月 限额）
- Monthly Active Users（5 万限额）

设置告警：**Settings** → **Billing** → **Spend cap** 启用免费套餐保护，超额自动停服而不是扣钱。

---

## ⚠️ 关于免费套餐"7 天暂停"

Supabase 免费项目 7 天没人用会暂停。**有家长来报名/教练登录就不会暂停。**

如果不小心暂停了：
1. 登录 Supabase Dashboard
2. 看到项目状态 paused → 点 **Restore project**
3. 等 30 秒就回来了，**数据完全保留**

正式有用户之后基本不会触发。担心的话升级到 Pro($25/月) 就完全没限制。

---

## 🆘 常见问题

**Q：教练账号密码忘了？**  
A：Supabase Dashboard → Authentication → Users → 你的邮箱 → 三点菜单 → Send password recovery。

**Q：admin 权限丢了怎么办？**  
A：你登录 Supabase（你拥有项目所有权）→ SQL Editor → 跑：
```sql
insert into app_admins (user_id, name)
values ((select id from auth.users where email = '你的邮箱'), 'Zoe Stella')
on conflict (user_id) do nothing;
```

**Q：Realtime 不工作怎么办？**  
A：检查建表 SQL 末尾的 `alter publication supabase_realtime add table ...` 是否成功执行。如果建表报错跳过了，单独再跑一遍这几行。

**Q：怎么彻底重置整个项目？**  
A：admin 后台 → 危险区 → 全部清空（输入 WIPE 确认）。或者 Supabase Dashboard 直接删项目重建。

**Q：手机怎么用？**  
A：把 GitHub Pages 链接添加到主屏幕：iOS Safari **分享 → 添加到主屏幕**；Android Chrome **三个点 → 添加到主屏幕**。

**Q：将来扩展到多教练？**  
A：在 SQL 里加一张 `coach_clients` 表记录哪些家长归哪个教练，调整 RLS 策略让教练只能看自己的学员。我可以帮你做这步迭代。

---

## 🚀 后续可以加的功能

- **邮件提醒**：循环申请被批准/拒绝、上课前 24h 提醒
  - 用 Resend（每月免费 3000 封）+ Supabase Edge Functions
  - 不用买域名，用 `onboarding@resend.dev` 共享发件人即可起步
- **家长邮箱验证**：避免别人冒用邮箱改预约
- **课包/课时余额**：付费购买、自动扣次
- **多教练扩展**：每个教练管自己的学员
- **教练课后笔记**：每节课记录孩子表现
- **Push 通知**：浏览器推送上课提醒（不用邮件）

部署成功后告诉我下一步想加什么，我帮你迭代。
