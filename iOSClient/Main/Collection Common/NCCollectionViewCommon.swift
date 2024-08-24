//
//  NCCollectionViewCommon.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/09/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import SwiftUI
import RealmSwift
import NextcloudKit
import EasyTipView
import JGProgressHUD

class NCCollectionViewCommon: UIViewController, UIGestureRecognizerDelegate, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate, NCListCellDelegate, NCGridCellDelegate, NCPhotoCellDelegate, NCSectionFirstHeaderDelegate, NCSectionFooterDelegate, NCSectionFirstHeaderEmptyDataDelegate, NCAccountSettingsModelDelegate, UIAdaptivePresentationControllerDelegate, UIContextMenuInteractionDelegate {

    @IBOutlet weak var collectionView: UICollectionView!

    var autoUploadFileName = ""
    var autoUploadDirectory = ""
    var isTransitioning: Bool = false
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    let refreshControl = UIRefreshControl()
    var searchController: UISearchController?
    var backgroundImageView = UIImageView()
    var serverUrl: String = ""
    var isEditMode = false
    var selectOcId: [String] = []
    var metadataFolder: tableMetadata?
    var dataSource = NCDataSource()
    var richWorkspaceText: String?
    var sectionFirstHeader: NCSectionFirstHeader?
    var sectionFirstHeaderEmptyData: NCSectionFirstHeaderEmptyData?
    var isSearchingMode: Bool = false
    var layoutForView: NCDBLayoutForView?
    var dataSourceTask: URLSessionTask?
    var providers: [NKSearchProvider]?
    var searchResults: [NKSearchResult]?
    var listLayout = NCListLayout()
    var gridLayout = NCGridLayout()
    var mediaLayout = NCMediaLayout()
    var layoutType = NCGlobal.shared.layoutList
    var literalSearch: String?
    var tabBarSelect: NCCollectionViewCommonSelectTabBar!
    var attributesZoomIn: UIMenuElement.Attributes = []
    var attributesZoomOut: UIMenuElement.Attributes = []
    let maxImageGrid: CGFloat = 7

    // DECLARE
    var layoutKey = ""
    var titleCurrentFolder = ""
    var titlePreviusFolder: String?
    var enableSearchBar: Bool = false
    var headerMenuTransferView = false
    var headerRichWorkspaceDisable: Bool = false
    var emptyImage: UIImage?
    var emptyTitle: String = ""
    var emptyDescription: String = ""
    var emptyDataPortaitOffset: CGFloat = 0
    var emptyDataLandscapeOffset: CGFloat = -20

    var session: NCSession.Session {
        NCSession.shared.getSession(controller: tabBarController)
    }

    var isLayoutPhoto: Bool {
        layoutForView?.layout == NCGlobal.shared.layoutPhotoRatio || layoutForView?.layout == NCGlobal.shared.layoutPhotoSquare
    }

    var isLayoutGrid: Bool {
        layoutForView?.layout == NCGlobal.shared.layoutGrid
    }

    var isLayoutList: Bool {
        layoutForView?.layout == NCGlobal.shared.layoutList
    }

    var showDescription: Bool {
        !headerRichWorkspaceDisable && NCKeychain().showDescription
    }

    var infoLabelsSeparator: String {
        layoutForView?.layout == NCGlobal.shared.layoutList ? " - " : ""
    }

    var sizeImage: CGSize {
        let columnCount: Int = self.layoutForView?.columnPhoto ?? 3
        let size = CGSize(width: collectionView.frame.width / CGFloat(columnCount), height: collectionView.frame.width / CGFloat(columnCount))
        return size
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        tabBarSelect = NCCollectionViewCommonSelectTabBar(controller: tabBarController as? NCMainTabBarController, delegate: self)
        self.navigationController?.presentationController?.delegate = self
        collectionView.alwaysBounceVertical = true

        // Color
        view.backgroundColor = .systemBackground
        collectionView.backgroundColor = .systemBackground
        refreshControl.tintColor = NCBrandColor.shared.textColor2

        if enableSearchBar {
            searchController = UISearchController(searchResultsController: nil)
            searchController?.searchResultsUpdater = self
            searchController?.obscuresBackgroundDuringPresentation = false
            searchController?.delegate = self
            searchController?.searchBar.delegate = self
            searchController?.searchBar.autocapitalizationType = .none
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = true
        }

        // Cell
        collectionView.register(UINib(nibName: "NCListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib(nibName: "NCGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")
        collectionView.register(UINib(nibName: "NCPhotoCell", bundle: nil), forCellWithReuseIdentifier: "photoCell")
        collectionView.register(UINib(nibName: "NCTransferCell", bundle: nil), forCellWithReuseIdentifier: "transferCell")

        // Header
        collectionView.register(UINib(nibName: "NCSectionFirstHeader", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionFirstHeader")
        collectionView.register(UINib(nibName: "NCSectionFirstHeader", bundle: nil), forSupplementaryViewOfKind: mediaSectionHeader, withReuseIdentifier: "sectionFirstHeader")
        collectionView.register(UINib(nibName: "NCSectionHeader", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionHeader")
        collectionView.register(UINib(nibName: "NCSectionHeader", bundle: nil), forSupplementaryViewOfKind: mediaSectionHeader, withReuseIdentifier: "sectionHeader")
        collectionView.register(UINib(nibName: "NCSectionFirstHeaderEmptyData", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionFirstHeaderEmptyData")
        collectionView.register(UINib(nibName: "NCSectionFirstHeaderEmptyData", bundle: nil), forSupplementaryViewOfKind: mediaSectionHeader, withReuseIdentifier: "sectionFirstHeaderEmptyData")

        // Footer
        collectionView.register(UINib(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")
        collectionView.register(UINib(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: mediaSectionFooter, withReuseIdentifier: "sectionFooter")

        // Refresh Control
        collectionView.refreshControl = refreshControl
        refreshControl.action(for: .valueChanged) { _ in
            self.dataSource.clearDirectory()
            NCManageDatabase.shared.cleanEtagDirectory(serverUrl: self.serverUrl, account: self.session.account)
            self.reloadDataSourceNetwork()
        }

        // Long Press on CollectionView
        let longPressedGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressCollecationView(_:)))
        longPressedGesture.minimumPressDuration = 0.5
        longPressedGesture.delegate = self
        longPressedGesture.delaysTouchesBegan = true
        collectionView.addGestureRecognizer(longPressedGesture)

        // Drag & Drop
        collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self

        let dropInteraction = UIDropInteraction(delegate: self)
        self.navigationController?.navigationItem.leftBarButtonItems?.first?.customView?.addInteraction(dropInteraction)

        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarAppearance()
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationItem.title = titleCurrentFolder

        isEditMode = false
        setNavigationLeftItems()
        setNavigationRightItems()

        layoutForView = NCManageDatabase.shared.getLayoutForView(account: session.account, key: layoutKey, serverUrl: serverUrl)
        if isLayoutList {
            collectionView?.collectionViewLayout = listLayout
            self.layoutType = NCGlobal.shared.layoutList
        } else if isLayoutGrid {
            collectionView?.collectionViewLayout = gridLayout
            self.layoutType = NCGlobal.shared.layoutGrid
        } else if layoutForView?.layout == NCGlobal.shared.layoutPhotoRatio {
            collectionView?.collectionViewLayout = mediaLayout
            self.layoutType = NCGlobal.shared.layoutPhotoRatio
        } else if layoutForView?.layout == NCGlobal.shared.layoutPhotoSquare {
            collectionView?.collectionViewLayout = mediaLayout
            self.layoutType = NCGlobal.shared.layoutPhotoSquare
        }

        // FIXME: iPAD PDF landscape mode iOS 16
        DispatchQueue.main.async {
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(_:)), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(closeRichWorkspaceWebView), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCloseRichWorkspaceWebView), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeStatusFolderE2EE(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadAvatar(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadAvatar), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSourceNetwork(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSourceNetwork), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(deleteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(moveFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(copyFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCopyFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(renameFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(createFolder(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCreateFolder), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(favoriteFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterFavoriteFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(downloadStartFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadStartFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(downloadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(downloadCancelFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadCancelFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(uploadStartFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadStartFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadedLivePhoto(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedLivePhoto), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uploadCancelFile(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadCancelFile), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(triggerProgressTask(_:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask), object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NCNetworking.shared.cancelUnifiedSearchFiles()
        dismissTip()

        // Cancel Queue & Retrieves Properties
        NCNetworking.shared.downloadThumbnailQueue.cancelAll()
        NCNetworking.shared.unifiedSearchQueue.cancelAll()
        dataSourceTask?.cancel()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCloseRichWorkspaceWebView), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeStatusFolderE2EE), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadAvatar), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSourceNetwork), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDeleteFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterMoveFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCopyFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterRenameFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterCreateFolder), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterFavoriteFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadStartFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadedFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterDownloadCancelFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadStartFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedFile), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadedLivePhoto), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterUploadCancelFile), object: nil)

        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterProgressTask), object: nil)
    }

    func presentationControllerDidDismiss( _ presentationController: UIPresentationController) {
        let viewController = presentationController.presentedViewController

        if viewController is NCViewerRichWorkspaceWebView {
            closeRichWorkspaceWebView()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        collectionView?.collectionViewLayout.invalidateLayout()
        collectionView?.reloadData()
        dismissTip()
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        if let frame = tabBarController?.tabBar.frame {
            tabBarSelect.hostingController?.view.frame = frame
        }
    }

    // MARK: - NotificationCenter

    @objc func applicationWillResignActive(_ notification: NSNotification) {
        self.refreshControl.endRefreshing()
    }

    @objc func reloadAvatar(_ notification: NSNotification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.showTip()
        }
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError,
              error.errorCode != NCGlobal.shared.errorNotModified else { return }

        setNavigationLeftItems()
    }

    @objc func changeTheming(_ notification: NSNotification) {
        collectionView.reloadData()
    }

    @objc func reloadDataSource(_ notification: NSNotification) {
        reloadDataSource()
    }

    @objc func reloadDataSourceNetwork(_ notification: NSNotification) {
        var withQueryDB = false

        if let userInfo = notification.userInfo as NSDictionary?,
           let reload = userInfo["withQueryDB"] as? Bool {
            withQueryDB = reload
        }

        if !isSearchingMode {
            reloadDataSourceNetwork(withQueryDB: withQueryDB)
        }
    }

    @objc func changeStatusFolderE2EE(_ notification: NSNotification) {
        reloadDataSource()
    }

    @objc func closeRichWorkspaceWebView() {
        reloadDataSourceNetwork()
    }

    @objc func deleteFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        if error == .success {
            reloadDataSource()
        } else {
            NCContentPresenter().showError(error: error)
        }
    }

    @objc func moveFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        if error == .success {
            if !isSearchingMode, let dragDrop = userInfo["dragdrop"] as? Bool, dragDrop {
                setEditMode(false)
                reloadDataSourceNetwork(withQueryDB: true)
            } else {
                reloadDataSource()
            }
        } else {
            NCContentPresenter().showError(error: error)
        }
    }

    @objc func copyFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let error = userInfo["error"] as? NKError else { return }

        if error == .success {
            if !isSearchingMode, let dragDrop = userInfo["dragdrop"] as? Bool, dragDrop {
                setEditMode(false)
                reloadDataSourceNetwork(withQueryDB: true)
            } else {
                reloadDataSource()
            }
        } else {
            NCContentPresenter().showError(error: error)
        }
    }

    @objc func renameFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let account = userInfo["account"] as? String,
              account == session.account
        else { return }

        reloadDataSource()
    }

    @objc func createFolder(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let ocId = userInfo["ocId"] as? String,
              let serverUrl = userInfo["serverUrl"] as? String,
              serverUrl == self.serverUrl,
              let account = userInfo["account"] as? String,
              account == session.account,
              let withPush = userInfo["withPush"] as? Bool
        else { return }

        reloadDataSource()

        if withPush, let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
            if let sceneIdentifier = userInfo["sceneIdentifier"] as? String {
                if sceneIdentifier == (self.tabBarController as? NCMainTabBarController)?.sceneIdentifier {
                    pushMetadata(metadata)
                }
            } else {
                pushMetadata(metadata)
            }
        }
    }

    @objc func favoriteFile(_ notification: NSNotification) {
        if self is NCFavorite {
            return reloadDataSource()
        }

        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              serverUrl == self.serverUrl
        else { return }

        reloadDataSource()
    }

    @objc func downloadStartFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String
        else { return }

        if account == self.session.account, serverUrl == self.serverUrl {
            self.reloadDataSource()
        } else {
            self.collectionView?.reloadData()
        }
    }

    @objc func downloadedFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String
        else { return }

        if account == self.session.account, serverUrl == self.serverUrl {
            self.reloadDataSource()
        } else {
            self.collectionView?.reloadData()
        }
    }

    @objc func downloadCancelFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String
        else { return }

        if account == self.session.account, serverUrl == self.serverUrl {
            self.reloadDataSource()
        } else {
            self.collectionView?.reloadData()
        }
    }

    @objc func uploadStartFile(_ notification: NSNotification) {
        self.collectionView?.reloadData()
    }

    @objc func uploadedFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String
        else { return }

        if account == self.session.account, serverUrl == self.serverUrl {
            self.reloadDataSource()
        } else {
            self.collectionView?.reloadData()
        }
    }

    @objc func uploadedLivePhoto(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String
        else { return }

        if account == self.session.account, serverUrl == self.serverUrl {
            self.reloadDataSource()
        } else {
            self.collectionView?.reloadData()
        }
    }

    @objc func uploadCancelFile(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let serverUrl = userInfo["serverUrl"] as? String,
              let account = userInfo["account"] as? String
        else { return }

        if account == self.session.account, serverUrl == self.serverUrl {
            self.reloadDataSource()
        } else {
            self.collectionView?.reloadData()
        }
    }

    @objc func triggerProgressTask(_ notification: NSNotification) {
        guard let userInfo = notification.userInfo as NSDictionary?,
              let progressNumber = userInfo["progress"] as? NSNumber,
              let totalBytes = userInfo["totalBytes"] as? Int64,
              let totalBytesExpected = userInfo["totalBytesExpected"] as? Int64,
              let ocId = userInfo["ocId"] as? String,
              let ocIdTransfer = userInfo["ocIdTransfer"] as? String,
              let session = userInfo["session"] as? String
        else { return }
        let chunk: Int = userInfo["chunk"] as? Int ?? 0
        let e2eEncrypted: Bool = userInfo["e2eEncrypted"] as? Bool ?? false
        let status = userInfo["status"] as? Int ?? NCGlobal.shared.metadataStatusNormal
        let transfer = NCTransferProgress.shared.append(NCTransferProgress.Transfer(ocId: ocId, ocIdTransfer: ocIdTransfer, session: session, chunk: chunk, e2eEncrypted: e2eEncrypted, progressNumber: progressNumber, totalBytes: totalBytes, totalBytesExpected: totalBytesExpected))

        // HEADER
        if self.headerMenuTransferView, transfer.session.contains("upload") {
            self.sectionFirstHeader?.setViewTransfer(isHidden: false, progress: transfer.progressNumber.floatValue)
            self.sectionFirstHeaderEmptyData?.setViewTransfer(isHidden: false, progress: transfer.progressNumber.floatValue)
        // DOWNLOAD
        } else if status == NCGlobal.shared.metadataStatusWaitDownload || status == NCGlobal.shared.metadataStatusDownloading {
            for case let cell as NCCellProtocol in self.collectionView.visibleCells {
                if cell.fileOcId == ocId {
                    cell.setProgress(progress: progressNumber.floatValue)
                    cell.fileInfoLabel?.text = self.utilityFileSystem.transformedSize(totalBytesExpected) + " - " + self.utilityFileSystem.transformedSize(totalBytes)
                }
            }
        }
    }

    // MARK: - Layout

    func setNavigationLeftItems() {
        guard layoutKey == NCGlobal.shared.layoutViewFiles,
              let tableAccount = NCManageDatabase.shared.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account)) else {
            return }
        let image = utility.loadUserImage(for: tableAccount.user, displayName: tableAccount.displayName, urlBase: tableAccount.urlBase)
        let accountButton = AccountSwitcherButton(type: .custom)
        let accounts = NCManageDatabase.shared.getAllAccountOrderAlias()
        var childrenAccountSubmenu: [UIMenuElement] = []

        accountButton.setImage(image, for: .normal)
        accountButton.setImage(image, for: .highlighted)
        accountButton.semanticContentAttribute = .forceLeftToRight
        accountButton.sizeToFit()

        if !accounts.isEmpty {
            let accountActions: [UIAction] = accounts.map { account in
                let image = utility.loadUserImage(for: account.user, displayName: account.displayName, urlBase: account.urlBase)
                var name: String = ""
                var url: String = ""

                if account.alias.isEmpty {
                    name = account.displayName
                    url = (URL(string: account.urlBase)?.host ?? "")
                } else {
                    name = account.alias
                }

                let action = UIAction(title: name, image: image, state: account.active ? .on : .off) { _ in
                    if !account.active {
                        NCAccount().changeAccount(account.account, userProfile: nil, controller: self.tabBarController as? NCMainTabBarController) { }
                        self.setEditMode(false)
                    }
                }

                action.subtitle = url
                return action
            }

            let addAccountAction = UIAction(title: NSLocalizedString("_add_account_", comment: ""), image: utility.loadImage(named: "person.crop.circle.badge.plus", colors: NCBrandColor.shared.iconImageMultiColors)) { _ in
                self.appDelegate.openLogin(selector: NCGlobal.shared.introLogin)
            }

            let settingsAccountAction = UIAction(title: NSLocalizedString("_account_settings_", comment: ""), image: utility.loadImage(named: "gear", colors: [NCBrandColor.shared.iconImageColor])) { _ in
                let accountSettingsModel = NCAccountSettingsModel(controller: self.tabBarController as? NCMainTabBarController, delegate: self)
                let accountSettingsView = NCAccountSettingsView(model: accountSettingsModel)
                let accountSettingsController = UIHostingController(rootView: accountSettingsView)
                self.present(accountSettingsController, animated: true, completion: nil)
            }

            if !NCBrandOptions.shared.disable_multiaccount {
                childrenAccountSubmenu.append(addAccountAction)
            }
            childrenAccountSubmenu.append(settingsAccountAction)

            let addAccountSubmenu = UIMenu(title: "", options: .displayInline, children: childrenAccountSubmenu)
            let menu = UIMenu(children: accountActions + [addAccountSubmenu])

            accountButton.menu = menu
            accountButton.showsMenuAsPrimaryAction = true

            accountButton.onMenuOpened = {
                self.dismissTip()
            }
        }

        navigationItem.leftItemsSupplementBackButton = true
        navigationItem.setLeftBarButtonItems([UIBarButtonItem(customView: accountButton)], animated: true)

        if titlePreviusFolder != nil {
            navigationController?.navigationBar.topItem?.title = titlePreviusFolder
        }

        navigationItem.title = titleCurrentFolder
    }

    func setNavigationRightItems() {
        guard layoutKey != NCGlobal.shared.layoutViewTransfers else { return }
        let isTabBarHidden = self.tabBarController?.tabBar.isHidden ?? true
        let isTabBarSelectHidden = tabBarSelect.isHidden()

        func createMenuActions() -> [UIMenuElement] {
            guard let layoutForView = NCManageDatabase.shared.getLayoutForView(account: session.account, key: layoutKey, serverUrl: serverUrl) else { return [] }
            let columnPhoto = self.layoutForView?.columnPhoto ?? 3

            func saveLayout(_ layoutForView: NCDBLayoutForView) {
                NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource)
                setNavigationRightItems()
            }

            if layoutForView.layout != NCGlobal.shared.layoutPhotoSquare && layoutForView.layout != NCGlobal.shared.layoutPhotoRatio {
                self.attributesZoomIn = .disabled
                self.attributesZoomOut = .disabled
            } else if CGFloat(columnPhoto) >= maxImageGrid - 1 {
                self.attributesZoomIn = []
                self.attributesZoomOut = .disabled
            } else if columnPhoto <= 1 {
                self.attributesZoomIn = .disabled
                self.attributesZoomOut = []
            } else {
                self.attributesZoomIn = []
                self.attributesZoomOut = []
            }

            let select = UIAction(title: NSLocalizedString("_select_", comment: ""), image: utility.loadImage(named: "checkmark.circle"), attributes: self.dataSource.getMetadataSourceForAllSections().isEmpty ? .disabled : []) { _ in
                self.setEditMode(true)
            }

            let list = UIAction(title: NSLocalizedString("_list_", comment: ""), image: utility.loadImage(named: "list.bullet"), state: layoutForView.layout == NCGlobal.shared.layoutList ? .on : .off) { _ in
                layoutForView.layout = NCGlobal.shared.layoutList
                self.layoutForView = NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
                self.layoutType = NCGlobal.shared.layoutList

                self.collectionView.reloadData()
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.listLayout, animated: true) {_ in self.isTransitioning = false }

                self.setNavigationRightItems()
            }

            let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""), image: utility.loadImage(named: "square.grid.2x2"), state: layoutForView.layout == NCGlobal.shared.layoutGrid ? .on : .off) { _ in
                layoutForView.layout = NCGlobal.shared.layoutGrid
                self.layoutForView = NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
                self.layoutType = NCGlobal.shared.layoutGrid

                self.collectionView.reloadData()
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.setCollectionViewLayout(self.gridLayout, animated: true) {_ in self.isTransitioning = false }

                self.setNavigationRightItems()
            }

            let menuPhoto = UIMenu(title: "", options: .displayInline, children: [
                UIAction(title: NSLocalizedString("_media_square_", comment: ""), image: utility.loadImage(named: "square.grid.3x3"), state: layoutForView.layout == NCGlobal.shared.layoutPhotoSquare ? .on : .off) { _ in
                    layoutForView.layout = NCGlobal.shared.layoutPhotoSquare
                    self.layoutForView = NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
                    self.layoutType = NCGlobal.shared.layoutPhotoSquare

                    self.collectionView.reloadData()
                    self.collectionView.collectionViewLayout.invalidateLayout()
                    self.collectionView.setCollectionViewLayout(self.mediaLayout, animated: true) {_ in self.isTransitioning = false }

                    self.reloadDataSource()
                    self.setNavigationRightItems()
                },
                UIAction(title: NSLocalizedString("_media_ratio_", comment: ""), image: utility.loadImage(named: "rectangle.grid.3x2"), state: layoutForView.layout == NCGlobal.shared.layoutPhotoRatio ? .on : .off) { _ in
                    layoutForView.layout = NCGlobal.shared.layoutPhotoRatio
                    self.layoutForView = NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)
                    self.layoutType = NCGlobal.shared.layoutPhotoRatio

                    self.collectionView.reloadData()
                    self.collectionView.collectionViewLayout.invalidateLayout()
                    self.collectionView.setCollectionViewLayout(self.mediaLayout, animated: true) {_ in self.isTransitioning = false }

                    self.reloadDataSource()
                    self.setNavigationRightItems()
                }
            ])

            let menuZoom = UIMenu(title: "", options: .displayInline, children: [
                UIAction(title: NSLocalizedString("_zoom_out_", comment: ""), image: utility.loadImage(named: "minus.magnifyingglass"), attributes: self.attributesZoomOut) { _ in
                    UIView.animate(withDuration: 0.0, animations: {
                        layoutForView.columnPhoto = columnPhoto + 1
                        self.layoutForView = NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)

                        self.collectionView.reloadData()
                        self.setNavigationRightItems()
                    })
                },
                UIAction(title: NSLocalizedString("_zoom_in_", comment: ""), image: utility.loadImage(named: "plus.magnifyingglass"), attributes: self.attributesZoomIn) { _ in
                    UIView.animate(withDuration: 0.0, animations: {
                        layoutForView.columnPhoto = columnPhoto - 1
                        self.layoutForView = NCManageDatabase.shared.setLayoutForView(layoutForView: layoutForView)

                        self.collectionView.reloadData()
                        self.setNavigationRightItems()
                    })
                }
            ])

            let viewStyleSubmenu = UIMenu(title: "", options: .displayInline, children: [list, grid, UIMenu(title: NSLocalizedString("_additional_view_options_", comment: ""), children: [menuPhoto, menuZoom])])

            let ascending = layoutForView.ascending
            let ascendingChevronImage = utility.loadImage(named: ascending ? "chevron.up" : "chevron.down")
            let isName = layoutForView.sort == "fileName"
            let isDate = layoutForView.sort == "date"
            let isSize = layoutForView.sort == "size"

            let byName = UIAction(title: NSLocalizedString("_name_", comment: ""), image: isName ? ascendingChevronImage : nil, state: isName ? .on : .off) { _ in
                if isName { // repeated press
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "fileName"
                saveLayout(layoutForView)
            }

            let byNewest = UIAction(title: NSLocalizedString("_date_", comment: ""), image: isDate ? ascendingChevronImage : nil, state: isDate ? .on : .off) { _ in
                if isDate { // repeated press
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "date"
                saveLayout(layoutForView)
            }

            let byLargest = UIAction(title: NSLocalizedString("_size_", comment: ""), image: isSize ? ascendingChevronImage : nil, state: isSize ? .on : .off) { _ in
                if isSize { // repeated press
                    layoutForView.ascending = !layoutForView.ascending
                }
                layoutForView.sort = "size"
                saveLayout(layoutForView)
            }

            let sortSubmenu = UIMenu(title: NSLocalizedString("_order_by_", comment: ""), options: .displayInline, children: [byName, byNewest, byLargest])

            let foldersOnTop = UIAction(title: NSLocalizedString("_directory_on_top_no_", comment: ""), image: utility.loadImage(named: "folder"), state: layoutForView.directoryOnTop ? .on : .off) { _ in
                layoutForView.directoryOnTop = !layoutForView.directoryOnTop
                saveLayout(layoutForView)
            }

            let personalFilesOnly = NCKeychain().getPersonalFilesOnly(account: session.account)
            let personalFilesOnlyAction = UIAction(title: NSLocalizedString("_personal_files_only_", comment: ""), image: utility.loadImage(named: "folder.badge.person.crop", colors: NCBrandColor.shared.iconImageMultiColors), state: personalFilesOnly ? .on : .off) { _ in
                NCKeychain().setPersonalFilesOnly(account: self.session.account, value: !personalFilesOnly)
                self.reloadDataSource()
            }

            let showDescriptionKeychain = NCKeychain().showDescription
            let showDescription = UIAction(title: NSLocalizedString("_show_description_", comment: ""), image: utility.loadImage(named: "list.dash.header.rectangle"), attributes: richWorkspaceText == nil ? .disabled : [], state: showDescriptionKeychain && richWorkspaceText != nil ? .on : .off) { _ in
                NCKeychain().showDescription = !showDescriptionKeychain
                self.collectionView.reloadData()
                self.setNavigationRightItems()
            }
            showDescription.subtitle = richWorkspaceText == nil ? NSLocalizedString("_no_description_available_", comment: "") : ""

            if layoutKey == NCGlobal.shared.layoutViewRecent {
                return [select]
            } else {
                var additionalSubmenu = UIMenu()
                if layoutKey == NCGlobal.shared.layoutViewFiles {
                    additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [foldersOnTop, personalFilesOnlyAction, showDescription])
                } else {
                    additionalSubmenu = UIMenu(title: "", options: .displayInline, children: [foldersOnTop, showDescription])
                }
                return [select, viewStyleSubmenu, sortSubmenu, additionalSubmenu]
            }
        }

        if isEditMode {
            tabBarSelect.update(selectOcId: selectOcId, metadatas: getSelectedMetadatas(), userId: session.userId)
            tabBarSelect.show()
            let select = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .done) {
                self.setEditMode(false)
            }
            navigationItem.rightBarButtonItems = [select]
        } else if navigationItem.rightBarButtonItems == nil || (!isEditMode && !tabBarSelect.isHidden()) {
            tabBarSelect.hide()
            let menuButton = UIBarButtonItem(image: utility.loadImage(named: "ellipsis.circle"), menu: UIMenu(children: createMenuActions()))
            menuButton.tintColor = NCBrandColor.shared.iconImageColor
            if layoutKey == NCGlobal.shared.layoutViewFiles {
                let notification = UIBarButtonItem(image: utility.loadImage(named: "bell"), style: .plain) {
                    if let viewController = UIStoryboard(name: "NCNotification", bundle: nil).instantiateInitialViewController() as? NCNotification {
                        viewController.session = self.session
                        self.navigationController?.pushViewController(viewController, animated: true)
                    }
                }
                notification.tintColor = NCBrandColor.shared.iconImageColor
                navigationItem.rightBarButtonItems = [menuButton, notification]
            } else {
                navigationItem.rightBarButtonItems = [menuButton]
            }
        } else {
            navigationItem.rightBarButtonItems?.first?.menu = navigationItem.rightBarButtonItems?.first?.menu?.replacingChildren(createMenuActions())
        }
        // fix, if the tabbar was hidden before the update, set it in hidden
        if isTabBarHidden, isTabBarSelectHidden {
            self.tabBarController?.tabBar.isHidden = true
        }
    }

    func getNavigationTitle() -> String {
        let tableAccount = NCManageDatabase.shared.getTableAccount(predicate: NSPredicate(format: "account == %@", session.account))
        if let tableAccount,
           !tableAccount.alias.isEmpty {
            return tableAccount.alias
        }
        return NCBrandOptions.shared.brand
    }

    func accountSettingsDidDismiss(tableAccount: tableAccount?, controller: NCMainTabBarController?) { }

    // MARK: - SEARCH

    func searchController(enabled: Bool) {
        guard enableSearchBar else { return }
        searchController?.searchBar.isUserInteractionEnabled = enabled
        if enabled {
            searchController?.searchBar.alpha = 1
        } else {
            searchController?.searchBar.alpha = 0.3

        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        self.literalSearch = searchController.searchBar.text
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        isSearchingMode = true
        self.providers?.removeAll()
        self.dataSource.clearDataSource()
        self.collectionView.reloadData()
        // TIP
        dismissTip()
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        if isSearchingMode && self.literalSearch?.count ?? 0 >= 2 {
            reloadDataSourceNetwork()
        }
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        DispatchQueue.global().async {
            NCNetworking.shared.cancelUnifiedSearchFiles()
            self.isSearchingMode = false
            self.literalSearch = ""
            self.providers?.removeAll()
            self.dataSource.clearDataSource()
            self.reloadDataSource()
        }
    }

    // MARK: - TAP EVENT

    func tapMoreListItem(with ocId: String, ocIdTransfer: String, namedButtonMore: String, image: UIImage?, indexPath: IndexPath, sender: Any) {
        tapMoreGridItem(with: ocId, ocIdTransfer: ocIdTransfer, namedButtonMore: namedButtonMore, image: image, indexPath: indexPath, sender: sender)
    }

    func tapMorePhotoItem(with ocId: String, ocIdTransfer: String, namedButtonMore: String, image: UIImage?, indexPath: IndexPath, sender: Any) {
        tapMoreGridItem(with: ocId, ocIdTransfer: ocIdTransfer, namedButtonMore: namedButtonMore, image: image, indexPath: indexPath, sender: sender)
    }

    func tapShareListItem(with ocId: String, ocIdTransfer: String, indexPath: IndexPath, sender: Any) {
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else { return }

        NCActionCenter.shared.openShare(viewController: self, metadata: metadata, page: .sharing)
    }

    func tapMoreGridItem(with ocId: String, ocIdTransfer: String, namedButtonMore: String, image: UIImage?, indexPath: IndexPath, sender: Any) {
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else { return }

        if namedButtonMore == NCGlobal.shared.buttonMoreMore || namedButtonMore == NCGlobal.shared.buttonMoreLock {
            toggleMenu(metadata: metadata, indexPath: indexPath, imageIcon: image)
        } else if namedButtonMore == NCGlobal.shared.buttonMoreStop {
            NCNetworking.shared.cancelTask(metadata: metadata)
        }
    }

    func tapRichWorkspace(_ sender: Any) {
        if let navigationController = UIStoryboard(name: "NCViewerRichWorkspace", bundle: nil).instantiateInitialViewController() as? UINavigationController {
            if let viewerRichWorkspace = navigationController.topViewController as? NCViewerRichWorkspace {
                viewerRichWorkspace.richWorkspaceText = richWorkspaceText ?? ""
                viewerRichWorkspace.serverUrl = serverUrl
                viewerRichWorkspace.delegate = self

                navigationController.modalPresentationStyle = .fullScreen
                self.present(navigationController, animated: true, completion: nil)
            }
        }
    }

    func tapButtonSection(_ sender: Any, metadataForSection: NCMetadataForSection?) {
        unifiedSearchMore(metadataForSection: metadataForSection)
    }

    func tapButtonTransfer(_ sender: Any) {
        NCTransferProgress.shared.getAll().forEach { transfer in
            if transfer.session == NCNetworking.shared.sessionUpload,
               let metadata = NCManageDatabase.shared.getMetadataFromOcIdAndocIdTransfer(transfer.ocIdTransfer) {
                NCNetworking.shared.cancelTask(metadata: metadata)
            }
        }
    }

    func longPressListItem(with ocId: String, ocIdTransfer: String, indexPath: IndexPath, gestureRecognizer: UILongPressGestureRecognizer) { }

    func longPressGridItem(with ocId: String, ocIdTransfer: String, indexPath: IndexPath, gestureRecognizer: UILongPressGestureRecognizer) { }

    func longPressMoreListItem(with ocId: String, ocIdTransfer: String, namedButtonMore: String, indexPath: IndexPath, gestureRecognizer: UILongPressGestureRecognizer) { }

    func longPressPhotoItem(with ocId: String, ocIdTransfer: String, indexPath: IndexPath, gestureRecognizer: UILongPressGestureRecognizer) { }

    func longPressMoreGridItem(with ocId: String, ocIdTransfer: String, namedButtonMore: String, indexPath: IndexPath, gestureRecognizer: UILongPressGestureRecognizer) { }

    @objc func longPressCollecationView(_ gestureRecognizer: UILongPressGestureRecognizer) {
        openMenuItems(with: nil, gestureRecognizer: gestureRecognizer)
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: {
            return nil
        }, actionProvider: { _ in
            return nil
        })
    }

    func openMenuItems(with objectId: String?, gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state != .began { return }

        var listMenuItems: [UIMenuItem] = []
        let touchPoint = gestureRecognizer.location(in: collectionView)

        becomeFirstResponder()

        if !serverUrl.isEmpty {
            listMenuItems.append(UIMenuItem(title: NSLocalizedString("_paste_file_", comment: ""), action: #selector(pasteFilesMenu)))
        }

        if !listMenuItems.isEmpty {
            UIMenuController.shared.menuItems = listMenuItems
            UIMenuController.shared.showMenu(from: collectionView, rect: CGRect(x: touchPoint.x, y: touchPoint.y, width: 0, height: 0))
        }
    }

    // MARK: - Menu Item

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {

        if #selector(pasteFilesMenu) == action {
            if !UIPasteboard.general.items.isEmpty, !(metadataFolder?.e2eEncrypted ?? false) {
                return true
            }
        } else if #selector(copyMenuFile) == action {
            return true
        } else if #selector(moveMenuFile) == action {
            return true
        }

        return false
    }

    @objc func pasteFilesMenu() {
        NCActionCenter.shared.pastePasteboard(serverUrl: serverUrl, account: session.account, hudView: tabBarController?.view)
    }

    // MARK: - DataSource + NC Endpoint

    func queryDB() { }

    @objc func reloadDataSource(withQueryDB: Bool = true) {
        guard !session.account.isEmpty, !self.isSearchingMode else { return }

        // get auto upload folder
        autoUploadFileName = NCManageDatabase.shared.getAccountAutoUploadFileName()
        autoUploadDirectory = NCManageDatabase.shared.getAccountAutoUploadDirectory(session: session)
        // get layout for view
        layoutForView = NCManageDatabase.shared.getLayoutForView(account: session.account, key: layoutKey, serverUrl: serverUrl)

        DispatchQueue.global(qos: .userInteractive).async {
            if withQueryDB { self.queryDB() }
            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()
                self.collectionView.reloadData()
                self.setNavigationRightItems()
            }
        }
    }

    @objc func reloadDataSourceNetwork(withQueryDB: Bool = false) {
        DispatchQueue.main.async {
            self.collectionView?.reloadData()
        }
    }

    @objc func networkSearch() {
        guard !session.account.isEmpty,
              let literalSearch = literalSearch,
              !literalSearch.isEmpty else {
            return self.refreshControl.endRefreshing()
        }

        self.dataSource.clearDataSource()
        self.refreshControl.beginRefreshing()
        self.collectionView.reloadData()

        if NCCapabilities.shared.getCapabilities(account: session.account).capabilityServerVersionMajor >= NCGlobal.shared.nextcloudVersion20 {
            NCNetworking.shared.unifiedSearchFiles(literal: literalSearch, account: session.account) { task in
                self.dataSourceTask = task
                self.collectionView.reloadData()
            } providers: { _, searchProviders in
                self.providers = searchProviders
                self.searchResults = []
                self.dataSource = NCDataSource(metadatas: [], layoutForView: self.layoutForView, providers: self.providers, searchResults: self.searchResults)
            } update: { _, _, searchResult, metadatas in
                guard let metadatas, !metadatas.isEmpty, self.isSearchingMode, let searchResult else { return }
                NCNetworking.shared.unifiedSearchQueue.addOperation(NCCollectionViewUnifiedSearch(collectionViewCommon: self, metadatas: metadatas, searchResult: searchResult))
            } completion: { _, _ in
                self.refreshControl.endRefreshing()
                self.collectionView.reloadData()
            }
        } else {
            NCNetworking.shared.searchFiles(literal: literalSearch, account: session.account) { task in
                self.dataSourceTask = task
                self.collectionView.reloadData()
            } completion: { metadatas, error in
                DispatchQueue.main.async {
                    self.refreshControl.endRefreshing()
                    self.collectionView.reloadData()
                }
                guard let metadatas = metadatas, error == .success, self.isSearchingMode else { return }
                self.dataSource = NCDataSource(metadatas: metadatas, layoutForView: self.layoutForView, providers: self.providers, searchResults: self.searchResults)
            }
        }
    }

    func unifiedSearchMore(metadataForSection: NCMetadataForSection?) {
        guard let metadataForSection = metadataForSection, let lastSearchResult = metadataForSection.lastSearchResult, let cursor = lastSearchResult.cursor, let term = literalSearch else { return }

        metadataForSection.unifiedSearchInProgress = true
        self.collectionView?.reloadData()

        NCNetworking.shared.unifiedSearchFilesProvider(id: lastSearchResult.id, term: term, limit: 5, cursor: cursor, account: session.account) { task in
            self.dataSourceTask = task
            self.collectionView.reloadData()
        } completion: { _, searchResult, metadatas, error in
            if error != .success {
                NCContentPresenter().showError(error: error)
            }

            metadataForSection.unifiedSearchInProgress = false
            guard let searchResult = searchResult, let metadatas = metadatas else { return }
            self.dataSource.appendMetadatasToSection(metadatas, metadataForSection: metadataForSection, lastSearchResult: searchResult)

            DispatchQueue.main.async {
                self.collectionView?.reloadData()
            }
        }
    }

    // MARK: - Push metadata

    func pushMetadata(_ metadata: tableMetadata) {
        guard let navigationCollectionViewCommon = (tabBarController as? NCMainTabBarController)?.navigationCollectionViewCommon else { return }
        let serverUrlPush = utilityFileSystem.stringAppendServerUrl(metadata.serverUrl, addFileName: metadata.fileName)

        if let viewController = navigationCollectionViewCommon.first(where: { $0.navigationController == self.navigationController && $0.serverUrl == serverUrlPush})?.viewController, viewController.isViewLoaded {
            navigationController?.pushViewController(viewController, animated: true)
        } else {
            if let viewController: NCFiles = UIStoryboard(name: "NCFiles", bundle: nil).instantiateInitialViewController() as? NCFiles {
                viewController.isRoot = false
                viewController.serverUrl = serverUrlPush
                viewController.titlePreviusFolder = navigationItem.title
                viewController.titleCurrentFolder = metadata.fileNameView

                navigationCollectionViewCommon.append(NavigationCollectionViewCommon(serverUrl: serverUrlPush, navigationController: self.navigationController, viewController: viewController))

                navigationController?.pushViewController(viewController, animated: true)
            }
        }
    }

    // MARK: - Header size

    func isHeaderMenuTransferViewEnabled() -> Results<tableMetadata>? {
        if headerMenuTransferView,
           let results = NCManageDatabase.shared.getResultsMetadatas(predicate: NSPredicate(format: "status == %d || status == %d",
                                                                                            NCGlobal.shared.metadataStatusWaitUpload,
                                                                                            NCGlobal.shared.metadataStatusUploading)),
           !results.isEmpty {
            return results
        }
        return nil
    }

    func getHeaderHeight(section: Int) -> (heightHeaderCommands: CGFloat, heightHeaderRichWorkspace: CGFloat, heightHeaderSection: CGFloat) {
        var headerRichWorkspace: CGFloat = 0

        func getHeaderHeight() -> CGFloat {
            var size: CGFloat = 0

            if isHeaderMenuTransferViewEnabled() != nil {
                if !isSearchingMode {
                    size += NCGlobal.shared.heightHeaderTransfer
                }
            }
            return size
        }

        if let richWorkspaceText = richWorkspaceText, showDescription {
            let trimmed = richWorkspaceText.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !isSearchingMode {
                headerRichWorkspace = UIScreen.main.bounds.size.height / 6
            }
        }

        if isSearchingMode || layoutForView?.groupBy != "none" || dataSource.numberOfSections() > 1 {
            if section == 0 {
                return (getHeaderHeight(), headerRichWorkspace, NCGlobal.shared.heightSection)
            } else {
                return (0, 0, NCGlobal.shared.heightSection)
            }
        } else {
            return (getHeaderHeight(), headerRichWorkspace, 0)
        }
    }

    func sizeForHeaderInSection(section: Int) -> CGSize {
        var height: CGFloat = 0

        if isEditMode {
            return CGSize.zero
        } else if dataSource.getMetadataSourceForAllSections().isEmpty {
            height = NCGlobal.shared.getHeightHeaderEmptyData(view: view, portraitOffset: emptyDataPortaitOffset, landscapeOffset: emptyDataLandscapeOffset, isHeaderMenuTransferViewEnabled: isHeaderMenuTransferViewEnabled() != nil)
        } else {
            let (heightHeaderCommands, heightHeaderRichWorkspace, heightHeaderSection) = getHeaderHeight(section: section)
            height = heightHeaderCommands + heightHeaderRichWorkspace + heightHeaderSection
        }
        return CGSize(width: collectionView.frame.width, height: height)
    }

    // MARK: - Footer size

    func sizeForFooterInSection(section: Int) -> CGSize {
        let sections = dataSource.numberOfSections()
        let metadataForSection = self.dataSource.getMetadataForSection(section)
        let isPaginated = metadataForSection?.lastSearchResult?.isPaginated ?? false
        let metadatasCount: Int = metadataForSection?.lastSearchResult?.entries.count ?? 0
        var size = CGSize(width: collectionView.frame.width, height: 0)

        if section == sections - 1 {
            size.height += NCGlobal.shared.endHeightFooter
        } else {
            size.height += NCGlobal.shared.heightFooter
        }

        if isSearchingMode && isPaginated && metadatasCount > 0 {
            size.height += NCGlobal.shared.heightFooterButton
        }
        return size
    }
}

// MARK: -

private class AccountSwitcherButton: UIButton {
    var onMenuOpened: (() -> Void)?

    override func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willDisplayMenuFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
        onMenuOpened?()
    }
}
