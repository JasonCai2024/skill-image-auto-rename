# MD 文档格式要求

本技能处理的 MD 文档**必须**满足以下结构，否则脚本会报错。

## 必备结构

每个分镜包含三部分（按顺序）：

1. **口播文案**（普通文本）
2. **prompt 代码块**（用 ` ```prompt ` 包裹的英文 AI 图片提示词）
3. **图片引用**（`![[xxx.png]]` 格式）

### 完整示例

```markdown
使用像 Codex 这样的 AI 编程智能体开发小工具时，
​```prompt
A relatable young man with messy brown hair wearing a green hoodie and blue jeans, sitting in front of a computer, looking determined. A friendly glowing blue AI coding robot assistant representing Codex...
​```
![[47-1-1.png]]

最难的不是你不会提需求，
​```prompt
a relatable young man with messy brown hair wearing a green hoodie and blue jeans pointing confidently at a large, clear holographic speech bubble with a light bulb icon inside...
​```
![[47-1-2.png]]
```

## 强制约束

### 1. prompt 代码块标识符必须 `prompt`

```markdown
✅ 正确：
​```prompt
绿衣男孩坐电脑前...
​```

❌ 错误（脚本抓不到）：
​```
绿衣男孩坐电脑前...
​```

❌ 错误（脚本抓不到）：
​```bash
绿衣男孩坐电脑前...
​```
```

脚本里写死匹配 ` ```prompt ... ``` `，其他语言标识符会**漏抓所有分镜**。

### 2. 图片引用格式必须 `![[xxx.png]]`

Obsidian 标准的 wiki link 格式：

```markdown
✅ 正确：
![[47-1-1.png]]
![[47-3.png]]
![[cover.png]]

❌ 错误（脚本抓不到）：
![47-1-1.png](47-1-1.png)
[图片](47-1-1.png)
```

### 3. prompt 块数 == 引用数

如果不一致，脚本会警告。常见原因：
- 某段口播文案**没有**配图 → 缺一个引用
- 某段口播文案**配了多张图**（如分镜细化）→ 多了一个引用

**修复方法**：手动调整 MD 文档，让两边数量一致。

## 命名约定

图片引用名的命名风格：

- 集数前缀 + 连字符 + 编号：`47-1-1.png`、`46-3.png`、`cover.png`
- 编号系统：分镜细化时用 `-1-1`、`-1-2` 等子编号

脚本**不限制**具体命名风格，只要求：
- 以 `.png` 结尾
- 在 MD 文档中唯一
- 与 prompt 块一一对应

## 文档示例（最简结构）

```markdown
# 第N集：标题

## 口播文案分镜设计

第一段口播文案
​```prompt
英文 prompt 1
​```
![[N-1.png]]

第二段口播文案
​```prompt
英文 prompt 2
​```
![[N-2.png]]

第三段口播文案
​```prompt
英文 prompt 3
​```
![[N-3.png]]
```

只要这个结构，脚本就能跑。
