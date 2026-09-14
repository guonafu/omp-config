#pragma once

#include <QVariantList>
#include <QString>

// 字段级最小化改写:在 models.yml 原文上只动目标 provider 的块,
// 未变化的行(注释、引号、缩进、其它字段/其它 provider)保持原样。
namespace ompyaml {

// 返回改写后的完整文本;若无需改动(结果与 original 相同)返回 original。
// 标量参数非空才改写,空 = 保留原值。
// 注:不保证写后 YAML 合法性 —— 调用方需再解析校验。
QString updateProvider(const QString &original,
                       const QString &providerName,
                       const QString &baseUrl,
                       const QString &apiKey,
                       const QString &api,
                       const QString &auth,
                       const QVariantList &models);

// config.yml 式顶层 map:按点分路径(如 "theme.dark"/"modelRoles.smol"/"display.showTokenUsage")
// 改写叶子值;只动存在的路径行,未触及行原样。数组用 flow 风格。
QString updateSettingPaths(const QString &original, const QVariantMap &patches);

// 移除整个 provider 块;无该 provider 返回原文。
QString removeProvider(const QString &original, const QString &providerName);

} // namespace ompyaml