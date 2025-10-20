## Research Schematic Agent（内部文档）

本流程用于把研究描述转为严格 JSON 提示，并在可控布局/风格/负面提示的约束下生成高分辨率学术示意图；若不满意，可通过表单回传增量修改点，进行保守编辑并返回新图。

### 一、如何导入（直接复制）
1) 打开 n8n 编辑器，右上角点击三点菜单 → Import from Clipboard。
2) 在本仓库中打开 `workflows/figure generator/research_schematic_agent.json`，复制全部内容后粘贴到弹窗，确认导入。
3) 导入后，确保各节点位置大致如下：`Form Input` → `Message a model` → `Parse Optimized JSON` → `Generate Image (gpt-image-1)` → `Wait for Feedback` → `Approved?` → `Wait` → `Edit an image`/`Merge`。

### 二、需要配置哪些东西

本流程用到两类凭证（Credentials）：
- OpenAI（用于 JSON 结构化与生图）
- Google Gemini(PaLM) Api（用于图片“保守编辑”）

> 安全提示：请仅在 n8n 的 Credentials 页面保存 API Key，不要把 Key 写进工作流节点或仓库文件。

#### 1) 配置 OpenAI 凭证
1. 在 n8n 左侧导航进入 Credentials → New。
2. 选择类型：OpenAI（或 `OpenAi`）。
3. Name：建议填写与你现有命名一致，例如 `OpenAi account`（或你已有的 `OpenAi account 2`）。
4. API Key：粘贴你的 OpenAI 密钥（示例：`sk-************************`）。
5. 保存。
6. 回到工作流：
   - 打开节点 `Message a model`，在 Credentials 下拉选择上面创建的 OpenAI 凭证。
   - 打开节点 `Generate Image (gpt-image-1)`，同样选择该 OpenAI 凭证。

#### 2) 配置 Google Gemini(PaLM) Api 凭证
1. 在 Credentials → New。
2. 选择类型：Google Gemini(PaLM) Api（有时在 n8n 中显示为 `GooglePalmApi`）。
3. Name：建议填写 `Google Gemini(PaLM) Api account`。
4. API Key：粘贴你的 Gemini(PaLM) 密钥（示例：`sk-************************`）。
5. 保存。
6. 回到工作流：打开节点 `Edit an image`，在 Credentials 下拉选择该凭证。

### 三、如何使用（怎么填）
1. 打开节点 `Form Input`，点击 Execute Node 以获得可访问的表单链接（或在运行工作流时自动弹出）。
2. 表单字段：
   - Research Description（必填）：粘贴研究计划/说明。
   - StylePrefs（可选）：风格/配色/排版偏好（如“矢量、蓝灰配色、细线、衬线标签”）。
   - Negatives（可选）：负面提示（如“霓虹、投影、写实纹理、厚重3D”）。
3. 提交后，`Message a model` 会生成严格 JSON；`Parse Optimized JSON` 规范化；`Generate Image (gpt-image-1)` 生成初稿。

### 四、怎么看结果
1. 在 `Generate Image (gpt-image-1)` 节点中：
   - 切换到 Binary 标签预览或下载生成的图片（默认 1024×1024）。
2. 在 `Parse Optimized JSON` 节点中：
   - 切换到 JSON 查看稳定结构（visual_prompt / negative_prompt / layout_constraints / style / icons）。
3. 若选择“需要调整”，将进入 `Wait` 节点填写具体修改点；随后 `Edit an image` 返回新图，亦可在 Binary 标签查看/下载。

### 五、如何二次调整（反馈回路）
1. 在 `Wait for Feedback` 表单选择：`需要调整` 或 `无需调整`。
2. 选择 `需要调整` 时，会弹出 `Wait` 表单，请尽量写清楚“只做这些改动”内容（如：箭头走向、标签文字、模块位置、配色细节）。
3. `Edit an image` 节点会执行“保守编辑”：
   - 保留已有语义结构、标签与拓扑，仅按请求的变动微调。
   - 白底、矢量感、箭头方向等硬约束保持不变。

### 六、可选项与参数
- 分辨率：在 `Generate Image (gpt-image-1)` → options.size 可改为 `512x512`, `1024x1024`, `2048x2048` 等。
- 版式/风格/负面提示：在 `Form Input` 提供；系统会自动注入到生图提示中以增强可控性。
- 图片编辑输入：如单独使用 `Edit an image`，请确保上游节点输出的图片二进制字段名为 `data`（本流程已通过 `Merge` 自动衔接，无需手动改名）。

### 七、常见问题（FAQ）
- 401/权限错误：检查 Credentials 是否已在对应节点选择，API Key 是否有效、未过期、未超配额。
- 无法预览图片：确认节点执行后在 Binary 标签查看；如二进制为空，检查上游是否执行成功。
- 生成风格不符合：在 `StylePrefs` 明确字体/线条粗细/配色/是否矢量；在 `Negatives` 加强排除项。
- 导入失败：确认是“Import from Clipboard”，并且粘贴的是完整 JSON（从 `{` 到 `}`）。

### 八、这套流程是做什么的（简述）
- 输入自然语言研究描述 → 结构化成严格 JSON → 带约束生图 → 人在环调优 → 保守编辑二次生成。
- 适用于：论文插图、系统结构图、算法流程图、对照实验方案示意等。

——
维护者备注：如需适配企业代理或私有 OpenAI 兼容网关，请在 OpenAI Credentials 中配置自定义 Base URL，并在相关节点选择该凭证即可。


