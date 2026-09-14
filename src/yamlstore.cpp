#include "yamlstore.h"

#include <QMetaType>
#include <QStringList>
#include <algorithm>

namespace yamlstore {

// ---------------------------------------------------------------------------
// 通用小工具
// ---------------------------------------------------------------------------
namespace {
struct Line { int indent; QString text; };

QString pad(int n) { return QString(n, QLatin1Char(' ')); }

// 去掉引号外的注释并去空白;空行/纯注释返回 false
bool stripCommentAndTrim(QString s, QString *out) {
    bool inS = false, inD = false;
    for (int i = 0; i < s.size(); ++i) {
        const QChar c = s.at(i);
        if (c == QLatin1Char('\'') && !inD) inS = !inS;
        else if (c == QLatin1Char('"') && !inS) inD = !inD;
        else if (c == QLatin1Char('#') && !inS && !inD
                 && (i == 0 || s.at(i - 1).isSpace())) {
            s = s.left(i);
            break;
        }
    }
    s = s.trimmed();
    if (s.isEmpty()) return false;
    *out = s;
    return true;
}

bool splitKeyValue(const QString &text, QString *key, QString *value) {
    bool inS = false, inD = false;
    for (int i = 0; i < text.size(); ++i) {
        const QChar c = text.at(i);
        if (c == QLatin1Char('\'') && !inD) inS = !inS;
        else if (c == QLatin1Char('"') && !inS) inD = !inD;
        else if (c == QLatin1Char(':') && !inS && !inD
                 && (i + 1 >= text.size() || text.at(i + 1).isSpace())) {
            *key = text.left(i).trimmed();
            *value = text.mid(i + 1).trimmed();
            return !key->isEmpty();
        }
    }
    return false;
}

QVariant scalarOf(const QString &s);

bool parseFlowArray(const QString &s, QVariantList *out) {
    if (!s.startsWith(QLatin1Char('[')) || !s.endsWith(QLatin1Char(']')))
        return false;
    const QString inner = s.mid(1, s.size() - 2);
    QVariantList list;
    QString cur;
    bool inS = false, inD = false;
    for (int i = 0; i <= inner.size(); ++i) {
        const QChar c = (i < inner.size()) ? inner.at(i) : QLatin1Char(',');
        if (c == QLatin1Char('\'') && !inD) { inS = !inS; cur.append(c); continue; }
        if (c == QLatin1Char('"') && !inS) { inD = !inD; cur.append(c); continue; }
        if (c == QLatin1Char(',') && !inS && !inD) {
            list.append(scalarOf(cur.trimmed()));
            cur.clear();
        } else {
            cur.append(c);
        }
    }
    if (!cur.isEmpty()) list.append(scalarOf(cur.trimmed()));
    *out = list;
    return true;
}

QVariant scalarOf(const QString &s) {
    QString t = s.trimmed();
    if (t.isEmpty()) return QVariant();
    if ((t.startsWith(QLatin1Char('"')) && t.endsWith(QLatin1Char('"')))
        || (t.startsWith(QLatin1Char('\'')) && t.endsWith(QLatin1Char('\'')))) {
        return t.mid(1, t.size() - 2); // 剥一层引号(含简单转义原样保留)
    }
    if (t == QLatin1String("true") || t == QLatin1String("True")) return true;
    if (t == QLatin1String("false") || t == QLatin1String("False")) return false;
    if (t == QLatin1String("null") || t == QLatin1String("~")) return QVariant();
    bool okInt = false;
    const qlonglong ll = t.toLongLong(&okInt);
    if (okInt) return QVariant(qint64(ll));
    if (t.contains(QLatin1Char('.')) || t.contains(QLatin1Char('e')) || t.contains(QLatin1Char('E'))) {
        bool okDbl = false;
        const double d = t.toDouble(&okDbl);
        if (okDbl) return d;
    }
    return t;
}
} // namespace

// ---------------------------------------------------------------------------
// 解析器
// ---------------------------------------------------------------------------
namespace {
class Parser {
public:
    QVector<Line> lines;
    int n = 0;
    int i = 0;

    QVariant run() {
        if (n == 0) return QVariantMap();
        return nodeAt(lines[i].indent);
    }

private:
    QVariant nodeAt(int indent) {
        if (i >= n || lines[i].indent < indent) return QVariantMap();
        const bool isList = lines[i].indent == indent && lines[i].text.startsWith(QLatin1Char('-'));
        if (isList) return parseList(indent);
        return parseMap(indent);
    }

    QVariant parseList(int indent) {
        QVariantList list;
        while (i < n && lines[i].indent == indent && lines[i].text.startsWith(QLatin1Char('-'))) {
            QString body = lines[i].text.mid(1).trimmed();
            ++i;
            const int itemIndent = indent + 2;
            if (body.isEmpty()) {
                if (i < n && lines[i].indent > indent) list.append(nodeAt(lines[i].indent));
                else list.append(QVariant());
            } else {
                QString key, val;
                if (splitKeyValue(body, &key, &val)) {
                    QVariantMap m;
                    QVariant v;
                    if (val.trimmed().isEmpty()) {
                        if (i < n && lines[i].indent > indent) v = nodeAt(lines[i].indent);
                        else v = QVariant();
                    } else {
                        QVariantList arr;
                        v = parseFlowArray(val.trimmed(), &arr) ? QVariant(arr) : scalarOf(val.trimmed());
                    }
                    m[key] = v;
                    // 该项 map 的其余兄弟键(itemIndent)
                    while (i < n && lines[i].indent == itemIndent && !lines[i].text.startsWith(QLatin1Char('-'))) {
                        QString k2, v2;
                        if (!splitKeyValue(lines[i].text, &k2, &v2)) { ++i; continue; }
                        QVariant vv;
                        if (v2.trimmed().isEmpty()) {
                            if (i + 1 < n && lines[i + 1].indent > itemIndent) { ++i; vv = nodeAt(lines[i].indent); }
                            else { vv = QVariant(); ++i; }
                        } else {
                            QVariantList arr;
                            vv = parseFlowArray(v2.trimmed(), &arr) ? QVariant(arr) : scalarOf(v2.trimmed());
                            ++i;
                        }
                        m[k2] = vv;
                    }
                    list.append(m);
                } else {
                    list.append(scalarOf(body));
                }
            }
        }
        return list;
    }

    QVariant parseMap(int indent) {
        QVariantMap m;
        while (i < n && lines[i].indent == indent && !lines[i].text.startsWith(QLatin1Char('-'))) {
            QString key, val;
            const QString text = lines[i].text;
            if (!splitKeyValue(text, &key, &val)) { ++i; continue; }
            if (val.trimmed().isEmpty()) {
                if (i + 1 < n && lines[i + 1].indent > indent) { ++i; m[key] = nodeAt(lines[i].indent); }
                else { m[key] = QVariant(); ++i; }
            } else {
                QVariantList arr;
                if (parseFlowArray(val.trimmed(), &arr)) m[key] = arr;
                else m[key] = scalarOf(val.trimmed());
                ++i;
            }
        }
        return m;
    }
};
} // namespace

QVariant parse(const QByteArray &data, QString *error) {
    Q_UNUSED(error);
    const QList<QByteArray> raw = data.split('\n');
    QVector<Line> lines;
    for (const QByteArray &r : raw) {
        const QString u = QString::fromUtf8(r);
        int indent = 0;
        while (indent < u.size() && u.at(indent) == QLatin1Char(' ')) ++indent;
        if (indent < u.size() && u.at(indent) == QLatin1Char('\t')) {
            if (error) *error = QStringLiteral("不支持 Tab 缩进");
            return QVariant();
        }
        QString text;
        if (!stripCommentAndTrim(u.mid(indent), &text)) continue;
        lines.append({ indent, text });
    }
    Parser p;
    p.lines = lines;
    p.n = lines.size();
    p.i = 0;
    return p.run();
}

// ---------------------------------------------------------------------------
// 序列化
// ---------------------------------------------------------------------------
namespace {

QString quoteScalar(const QString &s) {
    const QString special = QStringLiteral(": #\t\n\"'[]{},");
    bool needQuote = s.isEmpty();
    if (!needQuote && (s.at(0).isSpace() || s.at(0).isDigit()
                       || s.startsWith(QLatin1Char('-')) || s.startsWith(QLatin1Char('?'))
                       || s.startsWith(QLatin1Char('*')) || s.startsWith(QLatin1Char('&'))
                       || s.startsWith(QLatin1Char('[')) || s.startsWith(QLatin1Char('{'))))
        needQuote = true;
    if (!needQuote
        && (s == QLatin1String("true") || s == QLatin1String("false")
            || s == QLatin1String("null") || s == QLatin1String("True") || s == QLatin1String("False")
            || s == QLatin1String("yes") || s == QLatin1String("no")))
        needQuote = true;
    for (const QChar &c : s) {
        if (special.contains(c)) { needQuote = true; break; }
    }
    if (needQuote) {
        QString e = s;
        e.replace(QLatin1String("\\"), QLatin1String("\\\\"));
        e.replace(QLatin1String("\""), QLatin1String("\\\""));
        return QLatin1Char('"') + e + QLatin1Char('"');
    }
    return s;
}

QString scalarToString(const QVariant &v) {
    if (v.isNull()) return QStringLiteral("null");
    switch (v.typeId()) {
    case QMetaType::Bool: return v.toBool() ? QStringLiteral("true") : QStringLiteral("false");
    case QMetaType::Int:
    case QMetaType::UInt:
    case QMetaType::LongLong:
    case QMetaType::ULongLong: return QString::number(v.toLongLong());
    case QMetaType::Double: return QString::number(v.toDouble());
    default: return quoteScalar(v.toString());
    }
}

QStringList knownProviderKeys = { "baseUrl", "api", "auth", "apiKey", "transport",
    "disableStrictTools", "headers", "compat", "discovery", "remoteCompaction",
    "modelOverrides", "models" };
QStringList knownModelKeys = { "id", "name", "api", "baseUrl", "reasoning",
    "imageInputDecoder", "supportsTools", "thinking", "input", "cost",
    "premiumMultiplier", "contextWindow", "maxTokens", "omitMaxOutputTokens",
    "headers", "compat", "contextPromotionTarget", "compactionModel", "remoteCompaction" };

void dumpMapLines(QStringList *out, const QVariantMap &m, int indent, bool dash);
void dumpListLines(QStringList *out, const QVariantList &list, int indent);

void dumpMapLines(QStringList *out, const QVariantMap &m, int indent, bool dash) {
    QStringList keys;
    const bool providerLike = m.contains(QLatin1String("baseUrl")) || m.contains(QLatin1String("models"));
    const QStringList &order = providerLike ? knownProviderKeys : knownModelKeys;
    for (const QString &k : order)
        if (m.contains(k)) keys.append(k);
    for (auto it = m.cbegin(); it != m.cend(); ++it)
        if (!order.contains(it.key())) keys.append(it.key());

    for (int idx = 0; idx < keys.size(); ++idx) {
        const QString &k = keys.at(idx);
        const QVariant v = m.value(k);
        const int lineIndent = (dash && idx > 0) ? indent + 2 : indent;
        QString head = pad(lineIndent) + (dash && idx == 0 ? QStringLiteral("- ") : QString()) + k + QLatin1Char(':');
        switch (v.typeId()) {
        case QMetaType::QVariantMap: {
            const QVariantMap child = v.toMap();
            if (child.isEmpty()) { out->append(head + QStringLiteral(" {}")); break; }
            out->append(head);
            dumpMapLines(out, child, lineIndent + 2, false);
            break;
        }
        case QMetaType::QVariantList: {
            out->append(head);
            dumpListLines(out, v.toList(), lineIndent + 2);
            break;
        }
        default:
            out->append(head + QLatin1Char(' ') + scalarToString(v));
        }
    }
}

void dumpListLines(QStringList *out, const QVariantList &list, int indent) {
    for (const QVariant &it : list) {
        if (it.isNull()) {
            out->append(pad(indent) + QStringLiteral("-"));
            continue;
        }
        switch (it.typeId()) {
        case QMetaType::QVariantMap:
            dumpMapLines(out, it.toMap(), indent, true);
            break;
        case QMetaType::QVariantList:
            out->append(pad(indent) + QStringLiteral("-"));
            dumpListLines(out, it.toList(), indent + 1);
            break;
        default:
            out->append(pad(indent) + QStringLiteral("- ") + scalarToString(it));
        }
    }
}

} // namespace

QStringList orderedKeysForMap(const QVariantMap &map) {
    const bool providerLike = map.contains(QLatin1String("baseUrl")) || map.contains(QLatin1String("models"));
    const QStringList &order = providerLike ? knownProviderKeys : knownModelKeys;
    QStringList out;
    for (const QString &k : order)
        if (map.contains(k)) out.append(k);
    for (auto it = map.cbegin(); it != map.cend(); ++it)
        if (!order.contains(it.key())) out.append(it.key());
    return out;
}

QByteArray dumpMap(const QVariantMap &map) {
    QStringList lines;
    dumpMapLines(&lines, map, 0, false);
    QString text = lines.join(QLatin1Char('\n'));
    if (!text.isEmpty()) text += QLatin1Char('\n');
    return text.toUtf8();
}

QByteArray dump(const QVariant &node) {
    if (node.typeId() == QMetaType::QVariantMap)
        return dumpMap(node.toMap());
    QStringList lines;
    dumpListLines(&lines, node.toList(), 0);
    QString text = lines.join(QLatin1Char('\n'));
    if (!text.isEmpty()) text += QLatin1Char('\n');
    return text.toUtf8();
}

QByteArray dumpWithProvidersOrder(const QVariantMap &doc, const QStringList &providerOrder) {
    const QVariantMap providers = doc.value(QLatin1String("providers")).toMap();
    QStringList remaining;
    for (auto it = providers.cbegin(); it != providers.cend(); ++it)
        if (!providerOrder.contains(it.key())) remaining.append(it.key());
    std::sort(remaining.begin(), remaining.end());

    QStringList lines;
    lines << QStringLiteral("providers:");
    const auto emitProvider = [&](const QString &name) {
        const QVariant node = providers.value(name);
        if (node.typeId() != QMetaType::QVariantMap)
            return;
        QVariantMap single;
        single.insert(name, node);
        dumpMapLines(&lines, single, 2, false);
    };
    for (const QString &n : providerOrder)
        if (providers.contains(n)) emitProvider(n);
    for (const QString &n : remaining) emitProvider(n);

    QString text = lines.join(QLatin1Char('\n'));
    text += QLatin1Char('\n');
    return text.toUtf8();
}

} // namespace yamlstore