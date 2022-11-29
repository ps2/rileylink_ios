//
//  MinimedPumpSettingsView.swift
//  MinimedKitUI
//
//  Created by Pete Schwamb on 11/29/22.
//  Copyright © 2022 Pete Schwamb. All rights reserved.
//

import Foundation
import SwiftUI
import LoopKitUI

struct MinimedPumpSettingsView: View {

    @Environment(\.guidanceColors) private var guidanceColors

    @ObservedObject var viewModel: MinimedPumpSettingsViewModel

    @State private var showingDeletionSheet = false

    init(viewModel: MinimedPumpSettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            Section(content: {
                LabeledValueView(label: LocalizedString("Pump ID", comment: "Title for pump id row on MinimedPumpSettingsView"),
                                 value: "12345")

            }, header: {
                headerImage
            })
        }
        .insetGroupedListStyle()
        .navigationBarItems(trailing: doneButton)
        .navigationBarTitle(LocalizedString("Pump Settings", comment: "Navigation bar title for MinimedPumpSettingsView"))
    }

    private var deletePumpButton: some View {
        Button(action: {
            showingDeletionSheet = true
        }, label: {
            Text(LocalizedString("Delete Pump", comment: "Button label for removing Pump"))
                .foregroundColor(.red)
        }).actionSheet(isPresented: $showingDeletionSheet) {
            ActionSheet(
                title: Text("Are you sure you want to delete this Pump?"),
                buttons: [
                    .destructive(Text("Delete Pump")) {
                        viewModel.deletePump()
                    },
                    .cancel(),
                ]
            )
        }
    }

    private var headerImage: some View {
        VStack(alignment: .center) {
            Image(uiImage: viewModel.pumpImage)
                .resizable()
                .aspectRatio(contentMode: ContentMode.fit)
                .frame(height: 150)
                .padding(.horizontal)
        }.frame(maxWidth: .infinity)
    }

    private var doneButton: some View {
        Button("Done", action: {
            viewModel.didFinish()
        })
    }

}
