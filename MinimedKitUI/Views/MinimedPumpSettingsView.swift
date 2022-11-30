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
    @Environment(\.insulinTintColor) var insulinTintColor

    @ObservedObject var viewModel: MinimedPumpSettingsViewModel

    var supportedInsulinTypes: [InsulinType]

    @State private var showingDeletionSheet = false

    init(viewModel: MinimedPumpSettingsViewModel, supportedInsulinTypes: [InsulinType]) {
        self.viewModel = viewModel
        self.supportedInsulinTypes = supportedInsulinTypes
    }

    var body: some View {
        List {
            Section {
                headerImage
                    .padding(.vertical)
                HStack(alignment: .top) {
                    deliveryStatus
                    Spacer()
                    reservoirStatus
                }
                .padding(.bottom, 5)

            }

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
                }
            }

            Section(header: SectionHeader(label: LocalizedString("Configuration", comment: "The title of the configuration section in MinimedPumpManager settings")))
            {
                LabeledValueView(label: LocalizedString("Change Time Zone", comment: "The title of the command to change pump time zone"),
                                 value: viewModel.pumpManager.state.pumpID)
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
                LabeledValueView(label: LocalizedString("Pump Battery Type", comment: "The title text for the battery type value"),
                                 value: viewModel.pumpManager.state.pumpID)
                LabeledValueView(label: LocalizedString("Preferred Data Source", comment: "The title text for the preferred insulin data source config"),
                                 value: viewModel.pumpManager.state.pumpID)
                LabeledValueView(label: LocalizedString("Use MySentry", comment: "The title text for the preferred MySentry setting config"),
                                 value: viewModel.pumpManager.state.pumpID)

            }

            Section {
                LabeledValueView(label: LocalizedString("Pump ID", comment: "The title text for the pump ID config value"),
                                 value: viewModel.pumpManager.state.pumpID)
                LabeledValueView(label: LocalizedString("Firmware Version", comment: "The title of the cell showing the pump firmware version"),
                                 value: String(describing: viewModel.pumpManager.state.pumpFirmwareVersion))
                LabeledValueView(label: LocalizedString("Region", comment: "The title of the cell showing the pump region"),
                                 value: String(describing: viewModel.pumpManager.state.pumpRegion))
            }


            Section() {
                deletePumpButton
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
        .navigationBarTitle(String(format: LocalizedString("Medtronic %1$@", comment: "Format string fof navigation bar title for MinimedPumpSettingsView (1: model number)"), viewModel.pumpManager.state.pumpModel.description))
    }

    var deliverySectionTitle: String {
        if self.viewModel.isScheduledBasal {
            return LocalizedString("Scheduled Basal", comment: "Title of insulin delivery section")
        } else {
            return LocalizedString("Insulin Delivery", comment: "Title of insulin delivery section")
        }
    }

    var deliveryStatus: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(deliverySectionTitle)
                .foregroundColor(Color(UIColor.secondaryLabel))
            if viewModel.isSuspendedOrResuming {
                HStack(alignment: .center) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 34))
                        .fixedSize()
                        .foregroundColor(viewModel.suspendResumeButtonColor(guidanceColors: guidanceColors))
                    Text(LocalizedString("Insulin\nSuspended", comment: "Text shown in insulin delivery space when insulin suspended"))
                        .fontWeight(.bold)
                        .fixedSize()
                }
            } else if let basalRate = self.viewModel.basalDeliveryRate {
                HStack(alignment: .center) {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(viewModel.basalRateFormatter.string(from: basalRate) ?? "")
                            .font(.system(size: 28))
                            .fontWeight(.heavy)
                            .fixedSize()
                        Text(LocalizedString("U/hr", comment: "Units for showing temp basal rate"))
                            .foregroundColor(.secondary)
                    }
                }
            } else if viewModel.basalTransitioning {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 34))
                    .fixedSize()
                    .foregroundColor(.secondary)
                Text(LocalizedString("...", comment: "Text shown in basal rate space when basal is changing"))
                    .fontWeight(.bold)
                    .fixedSize()
            } else {
                HStack(alignment: .center) {
                    Image(systemName: "x.circle.fill")
                        .font(.system(size: 34))
                        .fixedSize()
                        .foregroundColor(guidanceColors.warning)
                    Text(LocalizedString("Unknown", comment: "Text shown in basal rate space when delivery status is unknown"))
                        .fontWeight(.bold)
                        .fixedSize()
                }
            }
        }
    }

    func reservoirColor(for reservoirLevelHighlightState: ReservoirLevelHighlightState) -> Color {
        switch reservoirLevelHighlightState {
        case .normal:
            return insulinTintColor
        case .warning:
            return guidanceColors.warning
        case .critical:
            return guidanceColors.critical
        }
    }

    var reservoirStatus: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(LocalizedString("Insulin Remaining", comment: "Header for insulin remaining on pod settings screen"))
                .foregroundColor(Color(UIColor.secondaryLabel))
            if let reservoirReading = viewModel.reservoirReading,
               let reservoirLevelHighlightState = viewModel.reservoirLevelHighlightState,
               let reservoirPercent = viewModel.reservoirPercentage
            {
                HStack {
                    MinimedReservoirView(filledPercent: reservoirPercent, fillColor: reservoirColor(for: reservoirLevelHighlightState))
                        .frame(width: 23, height: 32)
                    Text(viewModel.reservoirText(for: reservoirReading.units))
                        .font(.system(size: 28))
                        .fontWeight(.heavy)
                        .fixedSize()
                }
            }
        }
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
            viewModel.doneButtonPressed()
        })
    }

}
