#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QVariantList>
#include <QVariantMap>

// omp 配置后端:读写 ~/.omp/agent/models.yml,并把 provider 拉取其 models.
// 写回: 与已有结构合并(保留未知键) → 备份 *.bak-<ts> → 原子写(临时+rename) → 写后重解析校验。
class OmpConfigBackend : public QObject {
    Q_OBJECT
public:
    explicit OmpConfigBackend(QObject *parent = nullptr);

    // 返回 models.yml 的路径(默认 ~/.omp/agent/models.yml)
    static QString modelsPath();

    // ---- fetch: 拉取 provider 模型 ----
    Q_INVOKABLE void fetchModels(const QString &baseUrl, const QString &apiKey, const QString &auth);

    // ---- 读写 models.yml ----
    // 返回 providers: [{name, baseUrl?, api?, auth?, apiKey?}] (同步读文件)
    Q_INVOKABLE QVariantList loadProviders();
    // 返回某 provider 的 models: [{id,name,reasoning,input,contextWindow,maxTokens}]
    Q_INVOKABLE QVariantList loadProviderModels(const QString &providerName);

    // 保存(新建或覆盖)一个 provider 及其 models;成功返回 true
    Q_INVOKABLE bool saveProvider(const QString &name,
                                  const QString &baseUrl,
                                  const QString &apiKey,
                                  const QString &api,
                                  const QString &auth,
                                  const QVariantList &models);

signals:
    void modelsFetched(const QVariantList &ids);
    void fetchFailed(const QString &reason);
    void saved(bool ok, const QString &message);

private:
    // 读取并解析 models.yml;缺失/解析失败时返回空 map
    QVariantMap loadDoc();
    bool writeText(const QString &text, QString *errorOut);
    void handleFetchReply(QNetworkReply *reply);

    QNetworkAccessManager m_nam;
    QString m_error;
};