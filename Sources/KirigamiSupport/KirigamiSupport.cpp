#include "KirigamiSupport.h"
#include <KIconTheme>
#include <KLocalizedContext>
#include <KLocalizedString>
#include <QDir>
#include <QIcon>
#include <QNetworkAccessManager>
#include <QNetworkDiskCache>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlNetworkAccessManagerFactory>
#include <QQuickStyle>
#include <QStandardPaths>

// Disk-caching NAM factory — gives QML Image a 100 MB on-disk image cache
class CachingNetworkAccessManagerFactory : public QQmlNetworkAccessManagerFactory {
public:
  QNetworkAccessManager *create(QObject *parent) override {
    auto *manager = new QNetworkAccessManager(parent);
    auto *cache = new QNetworkDiskCache(manager);
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
                       + QStringLiteral("/images");
    cache->setCacheDirectory(cacheDir);
    cache->setMaximumCacheSize(100 * 1024 * 1024); // 100 MB
    manager->setCache(cache);
    return manager;
  }
};

void setupKirigamiPreApp() {}

void setupKirigamiPostApp() {
  // Setup KDE Icon Search Paths
  QStringList iconPaths = QIcon::themeSearchPaths();
  const auto genericDataPaths =
      QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation);
  for (const QString &path : genericDataPaths) {
    QString iconsPath = path + QStringLiteral("/icons");
    if (QDir(iconsPath).exists() && !iconPaths.contains(iconsPath)) {
      iconPaths << iconsPath;
    }
  }
  QIcon::setThemeSearchPaths(iconPaths);

  // Set a default theme name
  if (QIcon::themeName().isEmpty() ||
      QIcon::themeName() == QStringLiteral("hicolor")) {
    QIcon::setThemeName(QStringLiteral("breeze"));
  }

  KIconTheme::initTheme();
  KLocalizedString::setApplicationDomain("relic");

  // Force the desktop style if not explicitly overridden by the environment
  if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
    QQuickStyle::setStyle(QStringLiteral("org.kde.desktop"));
  }
}

void setupKirigamiEngine(void *enginePtr) {
  auto engine = static_cast<QQmlApplicationEngine *>(enginePtr);
  engine->rootContext()->setContextObject(new KLocalizedContext(engine));
  // Install the caching NAM factory so all QML Image loads are disk-cached
  engine->setNetworkAccessManagerFactory(new CachingNetworkAccessManagerFactory());
}
