//
//  NCDomain.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/08/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
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

import Foundation

public class NCDomain: NSObject {
    static let shared = NCDomain()

    public struct Domain {
        var account: String
        var urlBase: String
        var user: String
        var userId: String
        var sceneIdentifier: String
    }
    var domain: ThreadSafeArray<Domain> = ThreadSafeArray()

    public func addDomain(account: String, urlBase: String, user: String, userId: String, sceneIdentifier: String) {
        if self.domain.filter({ $0.account == account }).first != nil {
            return updateDomain(account, userId: userId, sceneIdentifier: sceneIdentifier)
        }
        self.domain.append(Domain(account: account, urlBase: urlBase, user: user, userId: userId, sceneIdentifier: sceneIdentifier))
    }

    public func updateDomain(_ account: String, userId: String? = nil, sceneIdentifier: String? = nil) {
        guard var domain = self.domain.filter({ $0.account == account }).first else { return }
        if let userId {
            domain.userId = userId
        }
        if let sceneIdentifier {
            domain.sceneIdentifier = sceneIdentifier
        }
    }

    public func removeDomain(account: String) {
        self.domain.remove(where: { $0.account == account })
    }

    public func getDomain(account: String) -> Domain? {
        return self.domain.filter({ $0.account == account }).first
    }

    public func getActiveDomain() -> Domain? {
        if let activeAccount = NCManageDatabase.shared.getActiveStringAccount(),
           let domain = self.domain.filter({ $0.account == activeAccount }).first {
            return domain
        }
        return nil
    }

    public func getActiveAccount() -> String {
        if let activeAccount = NCManageDatabase.shared.getActiveStringAccount(),
           let domain = self.domain.filter({ $0.account == activeAccount }).first {
            return domain.account
        }
        return ""
    }

    public func getActiveUrlBase() -> String {
        if let activeAccount = NCManageDatabase.shared.getActiveStringAccount(),
           let domain = self.domain.filter({ $0.account == activeAccount }).first {
            return domain.urlBase
        }
        return ""
    }

    public func getActiveUserId() -> String {
        if let activeAccount = NCManageDatabase.shared.getActiveStringAccount(),
           let domain = self.domain.filter({ $0.account == activeAccount }).first {
            return domain.userId
        }
        return ""
    }

    /*
     import Foundation

     @objc public protocol NCUserBaseUrl {
         var user: String { get }
         var urlBase: String { get }
         var account: String { get }
         var userId: String { get }
     }

     public extension NCUserBaseUrl {
         var userBaseUrl: String {
             user + "-" + (URL(string: urlBase)?.host ?? "")
         }
         var userAccount: String {
             user + " " + urlBase
         }
     }

     */
    public func getActiveUserBaseUrl() -> String {
        if let activeAccount = NCManageDatabase.shared.getActiveStringAccount() {
           return self.getUserBaseUrl(account: activeAccount)
        }
        return ""
    }

    public func getUserBaseUrl(account: String) -> String {
        guard let domain = self.domain.filter({ $0.account == account }).first else { return "" }
        return domain.user + "-" + (URL(string: domain.urlBase)?.host ?? "")
    }

}
