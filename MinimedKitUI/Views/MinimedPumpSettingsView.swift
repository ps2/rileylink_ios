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
import LoopKit

struct MinimedPumpSettingsView: View {

    @Environment(\.guidanceColors) private var guidanceColors

    @ObservedObject var viewModel: MinimedPumpSettingsViewModel

    var supportedInsulinTypes: [InsulinType]

    @State private var showingDeletionSheet = false

    init(viewModel: MinimedPumpSettingsViewModel, supportedInsulinTypes: [InsulinType]) {
        self.viewModel = viewModel
        self.supportedInsulinTypes = supportedInsulinTypes
    }

    var body: some View {
        List {
            Section(content: {
                LabeledValueView(label: LocalizedString("Pump ID", comment: "The title text for the pump ID config value"),
                                 value: viewModel.pumpManager.state.pumpID)
                LabeledValueView(label: LocalizedString("Pump Model", comment: "The title of the cell showing the pump model number"),
                                 value: String(describing: viewModel.pumpManager.state.pumpModel))
                LabeledValueView(label: LocalizedString("Firmware Version", comment: "The title of the cell showing the pump firmware version"),
                                 value: String(describing: viewModel.pumpManager.state.pumpFirmwareVersion))
                LabeledValueView(label: LocalizedString("Region", comment: "The title of the cell showing the pump region"),
                                 value: String(describing: viewModel.pumpManager.state.pumpRegion))
            }, header: {
                headerImage
            })

            if let basalDeliveryState = viewModel.basalDeliveryState {
                Section {
                    HStack {
                        Button(basalDeliveryState.buttonLabelText) {
                            viewModel.suspendResumeButtonPressed(action: basalDeliveryState.shownAction)
                        }.disabled(basalDeliveryState.isTransitioning)
                        if basalDeliveryState.isTransitioning {
                            Spacer()
                            ProgressView()
                        }
                    }
                    NavigationLink(destination: InsulinTypeSetting(initialValue: viewModel.pumpManager.state.insulinType, supportedInsulinTypes: supportedInsulinTypes, allowUnsetInsulinType: false, didChange: viewModel.didChangeInsulinType)) {
                        HStack {
                            Text(LocalizedString("Insulin Type", comment: "Text for confidence reminders navigation link")).foregroundColor(Color.primary)
                            if let currentTitle = viewModel.pumpManager.state.insulinType?.brandName {
                                Spacer()
                                Text(currentTitle)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .alert(item: $viewModel.activeAlert, content: { alert in
            switch alert {
            case .suspendError(let error):
                return Alert(title: Text(LocalizedString("Error Suspending", comment: "The alert title for a suspend error")),
                             message: Text(errorText(error)))
             case .resumeError(let error):
                return Alert(title: Text(LocalizedString("Error Resuming", comment: "The alert title for a resume error")),
                             message: Text(errorText(error)))
            case .syncTimeError(let error):
                return Alert(title: Text(LocalizedString("Error Syncing Time", comment: "The alert title for an error while synching time")),
                             message: Text(errorText(error)))
            }
        })

        .insetGroupedListStyle()
        .navigationBarItems(trailing: doneButton)
        .navigationBarTitle(LocalizedString("Pump Settings", comment: "Navigation bar title for MinimedPumpSettingsView"))
    }

    private func errorText(_ error: Error) -> String {
        if let error = error as? LocalizedError {
            return [error.localizedDescription, error.recoverySuggestion].compactMap{$0}.joined(separator: ". ")
        } else {
            return error.localizedDescription
        }
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
        }
        .frame(maxWidth: .infinity)
    }

    private var doneButton: some View {
        Button("Done", action: {
            viewModel.didFinish()
        })
    }

}
