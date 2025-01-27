// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Photos

class Albums: ObservableObject {
    @Published var smartAlbums: [PHAssetCollection] = []
}
