/*
 *   Copyright (C) 2014 Antonis Tsiapaliokas <antonis.tsiapaliokas@kde.org>
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License version 2,
 *   or (at your option) any later version, as published by the Free
 *   Software Foundation
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details
 *
 *   You should have received a copy of the GNU General Public
 *   License along with this program; if not, write to the
 *   Free Software Foundation, Inc.,
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

// Self
#include "applicationlistmodel.h"

// Qt
#include <QByteArray>
#include <QModelIndex>
#include <QProcess>

// KDE
#include <KPluginInfo>
#include <KService>
#include <KServiceGroup>
#include <KServiceTypeTrader>
#include <KSharedConfig>
#include <KSycoca>
#include <KSycocaEntry>
#include <KShell>
#include <KIOWidgets/KRun>
#include <QDebug>

ApplicationListModel::ApplicationListModel(QObject *parent)
    : QAbstractListModel(parent)
{
    //can't use the new syntax as this signal is overloaded
    connect(KSycoca::self(), SIGNAL(databaseChanged(const QStringList &)),
            this, SLOT(sycocaDbChanged(const QStringList &)));
}

ApplicationListModel::~ApplicationListModel()
= default;

QHash<int, QByteArray> ApplicationListModel::roleNames() const
{
    QHash<int, QByteArray> roleNames;
    roleNames[ApplicationNameRole] = "ApplicationNameRole";
    roleNames[ApplicationIconRole] = "ApplicationIconRole";
    roleNames[ApplicationStorageIdRole] = "ApplicationStorageIdRole";
    roleNames[ApplicationEntryPathRole] = "ApplicationEntryPathRole";
    roleNames[ApplicationOriginalRowRole] = "ApplicationOriginalRowRole";

    return roleNames;
}

void ApplicationListModel::sycocaDbChanged(const QStringList &changes)
{
    if (!changes.contains("apps") && !changes.contains("xdgdata-apps")) {
        return;
    }

    m_applicationList.clear();

    loadApplications();
}

bool appNameLessThan(const ApplicationData &a1, const ApplicationData &a2)
{
    return a1.name.toLower() < a2.name.toLower();
}

void ApplicationListModel::loadApplications()
{
    auto cfg = KSharedConfig::openConfig("applications-blacklistrc");
    auto blgroup = KConfigGroup(cfg, QStringLiteral("Applications"));

    // This is only temporary to get a clue what those apps' desktop files are called
    // I'll remove it once I've done a blacklist
    QStringList bl;

    QStringList blacklist = blgroup.readEntry("blacklist", QStringList());


    beginResetModel();

    m_applicationList.clear();

    KServiceGroup::Ptr group = KServiceGroup::root();
    if (!group || !group->isValid()) return;
    KServiceGroup::List subGroupList = group->entries(true);

    QMap<int, ApplicationData> orderedList;
    QList<ApplicationData> unorderedList;

    // Iterate over all entries in the group
    while (!subGroupList.isEmpty()) {
        KSycocaEntry::Ptr groupEntry = subGroupList.first();
        subGroupList.pop_front();

        if (groupEntry->isType(KST_KServiceGroup)) {
            KServiceGroup::Ptr serviceGroup(static_cast<KServiceGroup* >(groupEntry.data()));

            if (!serviceGroup->noDisplay()) {
                KServiceGroup::List entryGroupList = serviceGroup->entries(true);

                for(KServiceGroup::List::ConstIterator it = entryGroupList.constBegin();  it != entryGroupList.constEnd(); it++) {
                    KSycocaEntry::Ptr entry = (*it);

                    if (entry->isType(KST_KServiceGroup)) {
                        KServiceGroup::Ptr serviceGroup(static_cast<KServiceGroup* >(entry.data()));
                        subGroupList << serviceGroup;

                    } else if (entry->property("Exec").isValid()) {
                        KService::Ptr service(static_cast<KService* >(entry.data()));

                        qDebug() << " desktopEntryName: " << service->desktopEntryName();

                        if (service->isApplication() &&
                            !blacklist.contains(service->desktopEntryName()) &&
                            service->showOnCurrentPlatform() &&
                            !service->property("Terminal", QVariant::Bool).toBool()) {

                            bl << service->desktopEntryName();

                            ApplicationData data;
                            data.name = service->name();
                            data.icon = service->icon();
                            data.storageId = service->storageId();
                            data.entryPath = service->exec();

                            auto it = m_appPositions.constFind(service->storageId());
                            if (it != m_appPositions.constEnd()) {
                                orderedList[*it] = data;
                            } else {
                                unorderedList << data;
                            }
                        }
                    }
                }
            }
        }
    }

    blgroup.writeEntry("allapps", bl);
    blgroup.writeEntry("blacklist", blacklist);
    cfg->sync();

    std::sort(unorderedList.begin(), unorderedList.end(), appNameLessThan);
    m_applicationList << orderedList.values();
    m_applicationList << unorderedList;

    endResetModel();
    emit countChanged();
}

QVariant ApplicationListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid()) {
        return QVariant();
    }

    switch (role) {
    case Qt::DisplayRole:
    case ApplicationNameRole:
        return m_applicationList.at(index.row()).name;
    case ApplicationIconRole:
        return m_applicationList.at(index.row()).icon;
    case ApplicationStorageIdRole:
        return m_applicationList.at(index.row()).storageId;
    case ApplicationEntryPathRole:
        return m_applicationList.at(index.row()).entryPath;
    case ApplicationOriginalRowRole:
        return index.row();

    default:
        return QVariant();
    }
}

Qt::ItemFlags ApplicationListModel::flags(const QModelIndex &index) const
{
    if (!index.isValid())
        return nullptr;
    return Qt::ItemIsDragEnabled|QAbstractItemModel::flags(index);
}

int ApplicationListModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) {
        return 0;
    }

    return m_applicationList.count();
}

void ApplicationListModel::moveRow(const QModelIndex& /* sourceParent */, int sourceRow, const QModelIndex& /* destinationParent */, int destinationChild)
{
    moveItem(sourceRow, destinationChild);
}

void ApplicationListModel::setFavoriteItem(int row, bool favorite)
{
    if (row < 0 || row >= m_applicationList.length()) {
        return;
    }

    ApplicationData &data = m_applicationList[row];
    if (data.favorite == favorite) {
        return;
    }

    data.favorite = favorite;
    emit dataChanged(index(row, 0), index(row, 0));
}

void ApplicationListModel::setDesktopItem(int row, bool desktop)
{
    if (row < 0 || row >= m_applicationList.length()) {
        return;
    }

    ApplicationData &data = m_applicationList[row];
    if (data.desktop == desktop) {
        return;
    }

    data.desktop = desktop;
    emit dataChanged(index(row, 0), index(row, 0));
}

void ApplicationListModel::moveItem(int row, int destination)
{
    if (row < 0 || destination < 0 || row >= m_applicationList.length() ||
        destination >= m_applicationList.length() || row == destination) {
        return;
    }
    if (destination > row) {
        ++destination;
    }

    beginMoveRows(QModelIndex(), row, row, QModelIndex(), destination);
    if (destination > row) {
        ApplicationData data = m_applicationList.at(row);
        m_applicationList.insert(destination, data);
        m_applicationList.takeAt(row);
    } else {
        ApplicationData data = m_applicationList.takeAt(row);
        m_applicationList.insert(destination, data);
    }


    m_appOrder.clear();
    m_appPositions.clear();
    int i = 0;
    for (auto app : m_applicationList) {
        m_appOrder << app.storageId;
        m_appPositions[app.storageId] = i;
        ++i;
    }


    emit appOrderChanged();
    endMoveRows();
}

void ApplicationListModel::runApplication(const QString &storageId)
{
    if (storageId.isEmpty()) {
        return;
    }

    KService::Ptr service = KService::serviceByStorageId(storageId);

    KRun::runService(*service, QList<QUrl>(), nullptr);
}

QStringList ApplicationListModel::appOrder() const
{
    return m_appOrder;
}

void ApplicationListModel::setAppOrder(const QStringList &order)
{
    if (m_appOrder == order) {
        return;
    }

    m_appOrder = order;
    m_appPositions.clear();
    int i = 0;
    for (auto app : m_appOrder) {
        m_appPositions[app] = i;
        ++i;
    }
    emit appOrderChanged();
}
