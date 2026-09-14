#include "ompconfigbackend.h"
#include "yamlstore.h"
#include "yamlrewrite.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTemporaryFile>
#include <QDateTime>
#include <QUrl>
#include <QRegularExpression>
#include <QStandardPaths>

OmpConfigBackend::OmpConfigBackend(QObject *parent)
    : QObject(parent)
    , m_nam(this)
{
}

QString OmpConfigBackend::modelsPath()
{
    return QDir::homePath() + QStringLiteral("/.omp/agent/models.yml");
}

QString OmpConfigBackend::settingsPath()
{
    return QDir::homePath() + QStringLiteral("/.omp/agent/config.yml");
}

// ---------------------------------------------------------------------------
// fetch
// ---------------------------------------------------------------------------
void OmpConfigBackend::fetchModels(const QString &baseUrl, const QString &apiKey, const QString &auth)
{
    QUrl url(baseUrl.trimmed());
    if (url.isEmpty()) {
        emit fetchFailed(QStringLiteral("baseUrl 为空"));
        return;
    }
    if (!url.path().endsWith(QStringLiteral("/models")) && !url.path().endsWith(QStringLiteral("/models/")))
        url.setPath(url.path().endsWith(QLatin1Char('/')) ? url.path() + QLatin1String("models")
                                                          : url.path() + QLatin1String("/models"));

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    const QString authNorm = auth.trimmed().toLower();
    if (!apiKey.isEmpty() && authNorm != QLatin1String("none"))
        request.setRawHeader("Authorization", (QStringLiteral("Bearer ") + apiKey).toUtf8());

    QNetworkReply *reply = m_nam.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() { handleFetchReply(reply); });
}

void OmpConfigBackend::handleFetchReply(QNetworkReply *reply)
{
    reply->deleteLater();
    if (reply->error() != QNetworkReply::NoError) {
        emit fetchFailed(reply->errorString());
        return;
    }
    const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
    if (!doc.isObject()) {
        emit fetchFailed(QStringLiteral("响应不是合法 JSON"));
        return;
    }
    const QJsonObject obj = doc.object();
    QVariantList ids;
    if (obj.contains(QStringLiteral("data")) && obj.value(QStringLiteral("data")).isArray()) {
        const QJsonArray data = obj.value(QStringLiteral("data")).toArray();
        for (const QJsonValue &v : data) {
            const QJsonObject m = v.toObject();
            if (m.contains(QStringLiteral("id")) && m.value(QStringLiteral("id")).isString())
                ids.append(m.value(QStringLiteral("id")).toString());
        }
    } else {
        for (const QJsonValue &v : obj.value(QStringLiteral("models")).toArray())
            ids.append(v.toString());
    }
    if (ids.isEmpty()) {
        emit fetchFailed(QStringLiteral("响应中未找到模型 (data[].id)"));
        return;
    }
    emit modelsFetched(ids);
}

// ---------------------------------------------------------------------------
// 读写 models.yml
// ---------------------------------------------------------------------------
QVariantMap OmpConfigBackend::loadDoc()
{
    const QString path = modelsPath();
    QFile f(path);
    if (!f.exists())
        return QVariantMap();
    if (!f.open(QIODevice::ReadOnly)) {
        m_error = QStringLiteral("无法读取 ") + path;
        return QVariantMap();
    }
    const QVariant root = yamlstore::parse(f.readAll(), &m_error);
    if (root.typeId() != QVariant::Map) {
        if (m_error.isEmpty()) m_error = QStringLiteral("models.yml 解析失败");
        return QVariantMap();
    }
    return root.toMap();
}

QVariantList OmpConfigBackend::loadProviders()
{
    QVariantList out;
    const QVariantMap doc = loadDoc();
    const QVariant pv = doc.value(QStringLiteral("providers"));
    if (pv.typeId() != QVariant::Map)
        return out;
    const QVariantMap providers = pv.toMap();
    for (auto it = providers.cbegin(); it != providers.cend(); ++it) {
        QVariantMap item;
        item.insert(QStringLiteral("name"), it.key());
        if (it.value().typeId() == QVariant::Map) {
            const QVariantMap cfg = it.value().toMap();
            if (cfg.contains(QLatin1String("baseUrl"))) item.insert(QStringLiteral("baseUrl"), cfg.value(QStringLiteral("baseUrl")));
            if (cfg.contains(QLatin1String("api"))) item.insert(QStringLiteral("api"), cfg.value(QStringLiteral("api")));
            if (cfg.contains(QLatin1String("auth"))) item.insert(QStringLiteral("auth"), cfg.value(QStringLiteral("auth")));
            if (cfg.contains(QLatin1String("apiKey"))) item.insert(QStringLiteral("apiKey"), cfg.value(QStringLiteral("apiKey")));
        }
        out.append(item);
    }
    return out;
}

QVariantList OmpConfigBackend::loadProviderModels(const QString &providerName)
{
    QVariantList out;
    const QVariantMap doc = loadDoc();
    const QVariantMap providers = doc.value(QStringLiteral("providers")).toMap();
    const QVariant pv = providers.value(providerName);
    if (pv.typeId() != QVariant::Map)
        return out;
    const QVariantList models = pv.toMap().value(QStringLiteral("models")).toList();
    for (const QVariant &m : models) {
        if (m.typeId() != QVariant::Map) continue;
        QVariantMap item;
        const QVariantMap mm = m.toMap();
        if (mm.contains(QLatin1String("id"))) item.insert(QStringLiteral("id"), mm.value(QStringLiteral("id")));
        if (mm.contains(QLatin1String("name"))) item.insert(QStringLiteral("name"), mm.value(QStringLiteral("name")));
        if (mm.contains(QLatin1String("reasoning"))) item.insert(QStringLiteral("reasoning"), mm.value(QStringLiteral("reasoning")));
        if (mm.contains(QLatin1String("input"))) item.insert(QStringLiteral("input"), mm.value(QStringLiteral("input")));
        if (mm.contains(QLatin1String("contextWindow"))) item.insert(QStringLiteral("contextWindow"), mm.value(QStringLiteral("contextWindow")));
        if (mm.contains(QLatin1String("maxTokens"))) item.insert(QStringLiteral("maxTokens"), mm.value(QStringLiteral("maxTokens")));
        out.append(item);
    }
    return out;
}

bool OmpConfigBackend::writeText(const QString &text, QString *errorOut)
{
    return writeTextAt(modelsPath(), text, errorOut);
}

bool OmpConfigBackend::writeTextAt(const QString &path, const QString &text, QString *errorOut)
{
    // 校验: 重解析
    QString perr;
    const QVariant re = yamlstore::parse(text.toUtf8(), &perr);
    if (re.typeId() != QVariant::Map) {
        if (errorOut) *errorOut = QStringLiteral("写前校验失败: ") + (perr.isEmpty() ? QStringLiteral("YAML 非法") : perr);
        return false;
    }

    // 备份(仅当已存在)
    if (QFile::exists(path)) {
        const QString bak = path + QStringLiteral(".bak-") + QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmmss"));
        QFile::copy(path, bak);
    }

    // 原子写
    QTemporaryFile tmp(QDir::temp().filePath(QStringLiteral("omp-config-XXXXXX.yml")));
    if (!tmp.open()) {
        if (errorOut) *errorOut = QStringLiteral("无法创建临时文件");
        return false;
    }
    const QByteArray bytes = text.toUtf8();
    if (tmp.write(bytes) != bytes.size() || !tmp.flush()) {
        if (errorOut) *errorOut = QStringLiteral("写入临时文件失败");
        return false;
    }
    const QString tmpName = tmp.fileName();
    tmp.close();
    if (!QFile::remove(path) && QFile::exists(path)) {
        if (errorOut) *errorOut = QStringLiteral("无法替换原文件");
        QFile::remove(tmpName);
        return false;
    }
    if (!QFile::rename(tmpName, path)) {
        if (errorOut) *errorOut = QStringLiteral("临时文件改名失败");
        return false;
    }
    return true;
}

bool OmpConfigBackend::saveProvider(const QString &name,
                                    const QString &baseUrl,
                                    const QString &apiKey,
                                    const QString &api,
                                    const QString &auth,
                                    const QVariantList &models)
{
    if (name.trimmed().isEmpty()) {
        emit saved(false, QStringLiteral("provider 名称为空"));
        return false;
    }

    QFile f(modelsPath());
    QString orig;
    if (f.open(QIODevice::ReadOnly))
        orig = QString::fromUtf8(f.readAll());

    const QString authNorm = auth.trimmed().isEmpty() ? QStringLiteral("apiKey") : auth.trimmed();
    const QString newText = ompyaml::updateProvider(orig, name.trimmed(),
                                                    baseUrl, apiKey, api, authNorm, models);

    if (newText == orig) {
        emit saved(true, QStringLiteral("无变化（未写入）"));
        return true;
    }

    QString err;
    if (!writeText(newText, &err)) {
        emit saved(false, err);
        return false;
    }
    emit saved(true, QStringLiteral("已保存 provider：%1").arg(name));
    return true;
}

bool OmpConfigBackend::removeProvider(const QString &name)
{
    const QString n = name.trimmed();
    if (n.isEmpty()) {
        emit saved(false, QStringLiteral("provider 名称为空"));
        return false;
    }
    QFile f(modelsPath());
    QString orig;
    if (f.open(QIODevice::ReadOnly))
        orig = QString::fromUtf8(f.readAll());

    const QString newText = ompyaml::removeProvider(orig, n);
    if (newText == orig) {
        emit saved(true, QStringLiteral("无该 provider（未改）"));
        return true;
    }
    QString err;
    if (!writeText(newText, &err)) {
        emit saved(false, err);
        return false;
    }
    emit saved(true, QStringLiteral("已删除 provider：%1").arg(n));
    return true;
}

// ---------------------------------------------------------------------------
// config.yml 读写(外观 + 角色绑定)
// ---------------------------------------------------------------------------
QVariantMap OmpConfigBackend::loadConfigDoc()
{
    QFile f(settingsPath());
    if (!f.open(QIODevice::ReadOnly))
        return QVariantMap();
    return yamlstore::parse(f.readAll()).toMap();
}

void OmpConfigBackend::flatten(const QVariantMap &map, const QString &prefix, QVariantMap *out)
{
    for (auto it = map.cbegin(); it != map.cend(); ++it) {
        const QString key = prefix.isEmpty() ? it.key() : prefix + QLatin1Char('.') + it.key();
        if (it.value().typeId() == QMetaType::QVariantMap)
            flatten(it.value().toMap(), key, out);
        else
            out->insert(key, it.value());
    }
}

QVariantMap OmpConfigBackend::loadSettings()
{
    QVariantMap out;
    flatten(loadConfigDoc(), QString(), &out);
    return out;
}

bool OmpConfigBackend::saveSettings(const QVariantMap &patch)
{
    QFile f(settingsPath());
    QString orig;
    if (f.open(QIODevice::ReadOnly))
        orig = QString::fromUtf8(f.readAll());

    const QString newText = ompyaml::updateSettingPaths(orig, patch);
    if (newText == orig) {
        emit settingsSaved(true, QStringLiteral("无变化（未写入）"));
        return true;
    }
    QString err;
    if (!writeTextAt(settingsPath(), newText, &err)) {
        emit settingsSaved(false, err);
        return false;
    }
    emit settingsSaved(true, QStringLiteral("已保存设置"));
    return true;
}