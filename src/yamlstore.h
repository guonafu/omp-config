#pragma once

#include <QByteArray>
#include <QVariant>
#include <QString>

// 极简 YAML 子集读写器:覆盖 omp models.yml/config.yml 实际用到的结构
//   - 顶层 map;任意嵌套 map / sequence; '-' 序列项
//   - 标量: 裸、单/双引号、布尔 bool、整数/浮点、null
//   - 流式数组  [a, b, c]
//   - 注释 (#) 与空行忽略
// 写: 2 空格缩进、固定键序(已知键优先)、引号策略、裸布尔/数字。
// 用于把 GUI 编辑结果写回 models.yml 且保留未知字段。
namespace yamlstore {

// 解析 YAML 为通用 QVariant (QVariantMap / QVariantList / QString / double / bool / null)
QVariant parse(const QByteArray &data, QString *error = nullptr);

// 序列化 QVariant → YAML 文本(UTF-8)
QByteArray dump(const QVariant &node);

// 顶层带序输出:顶层仅含 providers 时,按 providerOrder 依次输出 provider,保持用户原始顺序。
// 顺序外的兜底项按字母追加。
QByteArray dumpWithProvidersOrder(const QVariantMap &doc, const QStringList &providerOrder);

// 若 value 为 map,按键序输出(先列已知键,其余按字母)
QByteArray dumpMap(const QVariantMap &map);

// 提供统一的键序(写 models.yml / config-го)
QStringList orderedKeysForMap(const QVariantMap &map);

} // namespace yamlstore