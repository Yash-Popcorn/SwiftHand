//
//  DictionaryPage.swift
//  CountMyActions
//
//  Created by pv on 9/9/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import SwiftUI

struct DictionaryPage: View {
    var body: some View {
        Image("asldict")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 500, height: 500)
    }
}

struct DictionaryPage_Previews: PreviewProvider {
    static var previews: some View {
        DictionaryPage()
    }
}
