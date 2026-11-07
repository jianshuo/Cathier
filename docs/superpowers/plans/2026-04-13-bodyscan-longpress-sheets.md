# 身体扫描长按弹出辞典 Sheet 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在身体扫描页面，长按感受 chip 弹出 `SensationDictionarySheet`，长按身体部位 chip 弹出 `BodyPartDictionarySheet`，复用觉察辞典已有的 Sheet 组件。

**Architecture:** 在 `BodyScanView` 中添加两个 `@State` 变量分别持有待展示的 `DictionaryEntry?`，通过 `.sheet(item:)` 弹出对应 Sheet。在每个 ChipView 上添加 `.onLongPressGesture` 触发查询 `DictionaryService` 并赋值。需要给 `DictionaryService` 添加两个按名查找的静态方法。

**Tech Stack:** SwiftUI, DictionaryService, existing SensationDictionarySheet / BodyPartDictionarySheet

---

## 文件结构

| 文件 | 动作 | 职责 |
|------|------|------|
| `Cathier/Services/DictionaryService.swift` | 修改 | 添加 `sensation(for:)` 和 `bodyPart(for:)` 查找方法 |
| `Cathier/Views/CheckIn/BodyScanView.swift` | 修改 | 添加长按手势 + sheet 呈现 |

无需新建文件。Sheet 组件 `SensationDictionarySheet` 和 `BodyPartDictionarySheet` 已在 `EmotionExplorerView.swift` 中定义且为模块级可访问。

---

### Task 1: DictionaryService 添加按名查找方法

**Files:**
- Modify: `Cathier/Services/DictionaryService.swift:88-106`

- [ ] **Step 1: 在 DictionaryService 中添加 sensation(for:) 和 bodyPart(for:)**

在 `DictionaryService` enum 的 `// MARK: - Body Parts` 区域后，添加两个查找方法：

```swift
// 在 bodyPartEntries 之后、sensationEntries 之前添加：

static func bodyPart(for name: String) -> DictionaryEntry? {
    shared.sections["bodyParts"]?.entries[name]
}

// 在 sensationEntries 之后添加：

static func sensation(for name: String) -> DictionaryEntry? {
    shared.sections["sensations"]?.entries[name]
}
```

这两个方法的 key 就是中文名（与 ConfigService.bodyParts 和 sensations 数组中的值一致）。

- [ ] **Step 2: 确认编译通过**

Run: Xcode Build (Cmd+B)
Expected: 编译成功，无新增 warning

- [ ] **Step 3: Commit**

```bash
git add Cathier/Services/DictionaryService.swift
git commit -m "feat: add sensation(for:) and bodyPart(for:) lookups to DictionaryService"
```

---

### Task 2: BodyScanView 添加长按手势和 Sheet

**Files:**
- Modify: `Cathier/Views/CheckIn/BodyScanView.swift`

- [ ] **Step 1: 添加两个 @State 变量用于驱动 sheet**

在 `BodyScanView` 的 `@Environment` 声明之后添加：

```swift
@State private var sensationSheetEntry: DictionaryEntry?
@State private var bodyPartSheetEntry: DictionaryEntry?
```

`DictionaryEntry` 需要遵循 `Identifiable`。但它目前不遵循。我们用一个包装结构体或者改用 `.sheet(isPresented:)` + 手动绑定。最简单的方案：用一个带 `Identifiable` 的包装。

**实际做法：** 因为 `DictionaryEntry` 没有实现 `Identifiable`，用 `.sheet(item:)` 需要一个 `Identifiable` wrapper。最简做法是用一个轻量包装：

```swift
private struct SheetItem: Identifiable {
    let id = UUID()
    let entry: DictionaryEntry
    enum Kind { case sensation, bodyPart }
    let kind: Kind
}

@State private var sheetItem: SheetItem?
```

- [ ] **Step 2: 在 ScrollView 上添加 .sheet(item:) modifier**

在 `BodyScanView` 的 `body` 中，在 `ScrollView { ... }` 之后、闭合大括号之前，添加 `.sheet(item:)` modifier：

```swift
.sheet(item: $sheetItem) { item in
    switch item.kind {
    case .sensation:
        SensationDictionarySheet(entry: item.entry)
    case .bodyPart:
        BodyPartDictionarySheet(entry: item.entry)
    }
}
```

- [ ] **Step 3: 给身体部位 chip 添加 .onLongPressGesture**

将现有的身体部位 ChipView 代码块（约第 15-22 行）：

```swift
ChipView(
    label: lm.display(part),
    isSelected: viewModel.selectedBodyParts.contains(part)
) {
    toggleBodyPart(part)
}
```

改为：

```swift
ChipView(
    label: lm.display(part),
    isSelected: viewModel.selectedBodyParts.contains(part)
) {
    toggleBodyPart(part)
}
.onLongPressGesture {
    if let entry = DictionaryService.bodyPart(for: part) {
        sheetItem = SheetItem(entry: entry, kind: .bodyPart)
    }
}
```

- [ ] **Step 4: 给感受 chip 添加 .onLongPressGesture**

将现有的感受 ChipView 代码块（约第 38-43 行）：

```swift
ChipView(
    label: lm.display(sensation),
    isSelected: viewModel.bodySensations[part]?.contains(sensation) ?? false
) {
    toggleSensation(sensation, for: part)
}
```

改为：

```swift
ChipView(
    label: lm.display(sensation),
    isSelected: viewModel.bodySensations[part]?.contains(sensation) ?? false
) {
    toggleSensation(sensation, for: part)
}
.onLongPressGesture {
    if let entry = DictionaryService.sensation(for: sensation) {
        sheetItem = SheetItem(entry: entry, kind: .sensation)
    }
}
```

- [ ] **Step 5: 确认编译通过**

Run: Xcode Build (Cmd+B)
Expected: 编译成功

- [ ] **Step 6: 手动测试**

1. 打开 App → 签到流程 → 身体扫描页
2. 长按一个身体部位（如「头部」）→ 应弹出 BodyPartDictionarySheet，显示该部位的详细信息
3. 短按部位仍正常切换选中状态
4. 选中一个身体部位后，在感受区域长按一个感受（如「紧绷」）→ 应弹出 SensationDictionarySheet
5. 短按感受仍正常切换选中状态
6. 关闭 Sheet 后，页面状态无异常

- [ ] **Step 7: Commit**

```bash
git add Cathier/Views/CheckIn/BodyScanView.swift
git commit -m "feat: long-press body part / sensation chips to show dictionary sheets"
```
