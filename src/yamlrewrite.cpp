#include "yamlrewrite.h"

#include "yamlstore.h"

#include <QRegularExpression>
#include <QVariantMap>
#include <QStringList>

namespace ompyaml {
namespace {

inline int indentOf(const QString &l) {
    int i = 0;
    while (i < l.size() && l.at(i) == QLatin1Char(' ')) ++i;
    return i;
}

bool isProviderKeyLine(const QString &line) {
    static const QRegularExpression re(QStringLiteral("^  [^#\\s][^:]*:\\s*$"));
    return re.match(line).hasMatch();
}

QString yamlquote(const QString &s) {
    if (s.isEmpty()) return QStringLiteral("\"\"");
    const QString special = QStringLiteral(": #\t\n\"'[]{},");
    bool need = false;
    if (s.at(0).isSpace() || s.at(0).isDigit()
        || s.startsWith(QLatin1Char('-')) || s.startsWith(QLatin1Char('?'))
        || s.startsWith(QLatin1Char('*')) || s.startsWith(QLatin1Char('&'))
        || s.startsWith(QLatin1Char('[')) || s.startsWith(QLatin1Char('{')))
        need = true;
    if (s == QLatin1String("true") || s == QLatin1String("false")
        || s == QLatin1String("null") || s == QLatin1String("True") || s == QLatin1String("False"))
        need = true;
    for (const QChar &c : s)
        if (special.contains(c)) { need = true; break; }
    return need ? (QLatin1Char('"') + s + QLatin1Char('"')) : s;
}

struct Item { QString id; QStringList lines; };

// 规范序列化一个 model 项 → 行(缩进 itemIndent)
QStringList canonicalModelLines(const QVariantMap &m, int itemIndent) {
    QStringList out;
    out << QString(itemIndent, QLatin1Char(' ')) + QStringLiteral("- id: ")
        + yamlquote(m.value(QStringLiteral("id")).toString());
    const QString name = m.value(QStringLiteral("name")).toString();
    if (!name.isEmpty())
        out << QString(itemIndent + 2, QLatin1Char(' ')) + QStringLiteral("name: ") + yamlquote(name);
    if (m.contains(QLatin1String("reasoning")))
        out << QString(itemIndent + 2, QLatin1Char(' ')) + QStringLiteral("reasoning: ")
            + (m.value(QStringLiteral("reasoning")).toBool() ? QStringLiteral("true") : QStringLiteral("false"));
    const QVariantList input = m.value(QStringLiteral("input")).toList();
    if (!input.isEmpty()) {
        out << QString(itemIndent + 2, QLatin1Char(' ')) + QStringLiteral("input:");
        for (const QVariant &v : input)
            out << QString(itemIndent + 4, QLatin1Char(' ')) + QStringLiteral("- ") + v.toString();
    }
    if (m.contains(QLatin1String("contextWindow")))
        out << QString(itemIndent + 2, QLatin1Char(' ')) + QStringLiteral("contextWindow: ")
            + QString::number(m.value(QStringLiteral("contextWindow")).toLongLong());
    if (m.contains(QLatin1String("maxTokens")))
        out << QString(itemIndent + 2, QLatin1Char(' ')) + QStringLiteral("maxTokens: ")
            + QString::number(m.value(QStringLiteral("maxTokens")).toLongLong());
    return out;
}

// 比较文件中的 model(经 yamlstore 解析)与 UI 提供的字段是否一致
bool modelFieldsEqual(const QVariantMap &file, const QVariantMap &ui) {
    const auto same = [](const QVariant &a, const QVariant &b) {
        if (a.typeId() == QVariant::List || b.typeId() == QVariant::List)
            return a.toList() == b.toList();
        if (a.typeId() == QVariant::String && b.typeId() == QVariant::String)
            return a.toString() == b.toString();
        return a == b;
    };
    const QStringList keys = { QStringLiteral("id"), QStringLiteral("name"),
                               QStringLiteral("reasoning"), QStringLiteral("input"),
                               QStringLiteral("contextWindow"), QStringLiteral("maxTokens") };
    for (const QString &k : keys) {
        if (file.contains(k) || ui.contains(k)) {
            if (!file.contains(k) || !ui.contains(k)) return false;
            if (!same(file.value(k), ui.value(k))) return false;
        }
    }
    return true;
}

} // namespace

QString updateProvider(const QString &original,
                       const QString &providerName,
                       const QString &baseUrl,
                       const QString &apiKey,
                       const QString &api,
                       const QString &auth,
                       const QVariantList &models)
{
    const QStringList all = original.split(QLatin1Char('\n'));
    const QString keyLine = QStringLiteral("  ") + providerName + QLatin1Char(':');

    // ---- 定位 provider 块 ----
    int start = -1;
    for (int i = 0; i < all.size(); ++i)
        if (all.at(i) == keyLine) { start = i; break; }
    int end = all.size();
    if (start >= 0)
        for (int i = start + 1; i < all.size(); ++i)
            if (isProviderKeyLine(all.at(i))) { end = i; break; }

    // ---- 新增 provider ----
    if (start < 0) {
        QStringList block;
        block << QStringLiteral("providers:") << keyLine;
        if (!baseUrl.isEmpty()) block << QStringLiteral("    baseUrl: ") + yamlquote(baseUrl);
        if (!api.isEmpty())     block << QStringLiteral("    api: ") + yamlquote(api);
        if (!auth.isEmpty())    block << QStringLiteral("    auth: ") + yamlquote(auth);
        if (!apiKey.isEmpty())  block << QStringLiteral("    apiKey: ") + yamlquote(apiKey);
        if (!models.isEmpty()) {
            block << QStringLiteral("    models:");
            for (const QVariant &mv : models) block += canonicalModelLines(mv.toMap(), 6);
        }
        QStringList out = all;
        while (!out.isEmpty() && out.last().trimmed().isEmpty()) out.removeLast();
        out += QString();
        out += block; // 空行 + 新块
        return out.join(QLatin1Char('\n')) + QLatin1Char('\n');
    }

    // ---- 定位 models 行 ----
    int modelsLine = -1;
    for (int i = start; i < end; ++i)
        if (indentOf(all.at(i)) == 4 && all.at(i).trimmed() == QLatin1String("models:")) { modelsLine = i; break; }

    QStringList result = all; // 工作副本(行级改写)

    // ---- 1) 标量改写(仅当 key 行存在且值非空) ----
    const struct { QString key; QString val; } scalars[] = {
        { QStringLiteral("baseUrl"), baseUrl },
        { QStringLiteral("api"), api },
        { QStringLiteral("auth"), auth },
        { QStringLiteral("apiKey"), apiKey },
    };
    for (const auto &sc : scalars) {
        if (sc.val.isEmpty()) continue;
        const QString prefix = QStringLiteral("    ") + sc.key + QLatin1Char(':');
        for (int i = start; i < end; ++i) {
            const QString l = all.at(i);
            if (indentOf(l) == 4 && l.trimmed().startsWith(sc.key + QLatin1Char(':'))) {
                const int colon = l.indexOf(QLatin1Char(':'));
                QString head = l.left(colon + 1);                 // "    key:"
                // 保留原 key 后的分隔空格风格
                int ws = 0;
                for (int k = colon + 1; k < l.size() && l.at(k).isSpace(); ++k) ++ws;
                result[i] = head + QString(qMax(ws, 1), QLatin1Char(' ')) + yamlquote(sc.val);
                break;
            }
        }
    }

    // ---- 2) models 区改写 ----
    QList<Item> items;
    int itemIndent = 6; // 规范缩进;以既有为准
    if (modelsLine >= 0) {
        int i = modelsLine + 1;
        // 推断 itemIndent
        for (int j = modelsLine + 1; j < end; ++j) {
            const QString l = all.at(j);
            const int ind = indentOf(l);
            if (l.mid(ind).startsWith(QLatin1Char('-'))) { itemIndent = ind; break; }
        }
        while (i < end) {
            const QString l = all.at(i);
            if (l.trimmed().isEmpty()) { ++i; continue; }
            const int ind = indentOf(l);
            if (!l.mid(ind).startsWith(QLatin1Char('-'))) { ++i; continue; } // 非 item 行(理论不应有)
            // 该 item 块
            Item it;
            static const QRegularExpression idRe(QStringLiteral("-\\s*id:\\s*([^\\s#]+)"));
            const QRegularExpressionMatch m = idRe.match(l.mid(ind));
            it.id = m.hasMatch() ? m.captured(1) : QString();
            const int bStart = i;
            ++i;
            while (i < end) {
                const QString nl = all.at(i);
                if (nl.trimmed().isEmpty()) { ++i; continue; }
                if (indentOf(nl) <= itemIndent) break;
                ++i;
            }
            it.lines = QStringList(all.mid(bStart, i - bStart));
            items << it;
        }
    }

    // 构建新 models 区
    QStringList newModelsRegion;
    if (!models.isEmpty()) {
        newModelsRegion << QStringLiteral("    models:");
        for (const QVariant &mv : models) {
            const QVariantMap ui = mv.toMap();
            const QString id = ui.value(QStringLiteral("id")).toString();
            // 复用未变化的原项
            bool reused = false;
            for (const Item &it : items) {
                if (it.id != id) continue;
                const QVariant parsedItem = yamlstore::parse((it.lines.join(QLatin1Char('\n')) + QLatin1Char('\n')).toUtf8());
                const QVariantMap fileModel = parsedItem.typeId() == QVariant::List
                    ? parsedItem.toList().value(0).toMap() : parsedItem.toMap();
                if (modelFieldsEqual(fileModel, ui)) {
                    newModelsRegion += it.lines; // 原样(保注释/格式)
                    reused = true;
                }
                break;
            }
            if (!reused)
                newModelsRegion += canonicalModelLines(ui, itemIndent);
        }
    }

    // ---- 3) 组装 ----
    QStringList out;
    out.reserve(all.size());
    for (int i = 0; i < start; ++i) out << result.at(i);          // 头部
    if (modelsLine >= 0) {
        for (int i = start; i < modelsLine; ++i) out << result.at(i); // provider 头(标量已改)
        if (!newModelsRegion.isEmpty()) out += newModelsRegion;       // models 区
    } else {
        for (int i = start; i < end; ++i) out << result.at(i);        // provider 全部
        if (!newModelsRegion.isEmpty()) out += newModelsRegion;       // 补 models
    }
    for (int i = end; i < all.size(); ++i) out << all.at(i);          // 尾部(其它 provider)

    QString text = out.join(QLatin1Char('\n'));
    if (text == original) return original;             // 无真实改动 → 原样(且不触发写)
    if (original.endsWith(QLatin1Char('\n'))) text += QLatin1Char('\n');
    return text;
}

} // namespace ompyaml