//
//  PodSettingsView.swift
//  OmniKitUI
//
//  Created by Pete Schwamb on 1/31/21.
//  Copyright © 2021 Pete Schwamb. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import OmniKit
import RileyLinkBLEKit

struct PodSettingsView: View  {
    
    @ObservedObject var viewModel: PodSettingsViewModel
    
    @State private var showingDeleteConfirmation = false
    
    @State private var showSuspendOptions = false;
    
    @Environment(\.guidanceColors) var guidanceColors
    @Environment(\.insulinTintColor) var insulinTintColor
    
    private var daysRemaining: Int? {
        if case .timeRemaining(let remaining) = viewModel.lifeState, remaining > .days(1) {
            return Int(remaining.days)
        }
        return nil
    }
    
    private var hoursRemaining: Int? {
        if case .timeRemaining(let remaining) = viewModel.lifeState, remaining > .hours(1) {
            return Int(remaining.hours.truncatingRemainder(dividingBy: 24))
        }
        return nil
    }
    
    private var minutesRemaining: Int? {
        if case .timeRemaining(let remaining) = viewModel.lifeState, remaining < .hours(2) {
            return Int(remaining.minutes.truncatingRemainder(dividingBy: 60))
        }
        return nil
    }
    
    func timeComponent(value: Int, units: String) -> some View {
        Group {
            Text(String(value)).font(.system(size: 28)).fontWeight(.heavy)
            Text(units).foregroundColor(.secondary)
        }
    }
    
    var lifecycleProgress: some View {
        VStack(spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(self.viewModel.lifeState.localizedLabelText)
                    .foregroundColor(self.viewModel.lifeState.labelColor(using: guidanceColors))
                Spacer()
                daysRemaining.map { (days) in
                    timeComponent(value: days, units: days == 1 ?
                        LocalizedString("day", comment: "Unit for singular day in pod life remaining") :
                        LocalizedString("days", comment: "Unit for plural days in pod life remaining"))
                }
                hoursRemaining.map { (hours) in
                    timeComponent(value: hours, units: hours == 1 ?
                        LocalizedString("hour", comment: "Unit for singular hour in pod life remaining") :
                        LocalizedString("hours", comment: "Unit for plural hours in pod life remaining"))
                }
                minutesRemaining.map { (minutes) in
                    timeComponent(value: minutes, units: minutes == 1 ?
                        LocalizedString("minute", comment: "Unit for singular minute in pod life remaining") :
                        LocalizedString("minutes", comment: "Unit for plural minutes in pod life remaining"))
                }
            }
            ProgressView(progress: CGFloat(self.viewModel.lifeState.progress)).accentColor(self.viewModel.lifeState.progressColor(insulinTintColor: insulinTintColor, guidanceColors: guidanceColors))
        }
    }
    
    var timeZoneString: String {
        let localTimeZone = TimeZone.current
        let localTimeZoneName = localTimeZone.abbreviation() ?? localTimeZone.identifier
        
        let timeZoneDiff = TimeInterval(viewModel.timeZone.secondsFromGMT() - localTimeZone.secondsFromGMT())
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        let diffString = timeZoneDiff != 0 ? formatter.string(from: abs(timeZoneDiff)) ?? String(abs(timeZoneDiff)) : ""
        
        return String(format: LocalizedString("%1$@%2$@%3$@", comment: "The format string for displaying an offset from a time zone: (1: GMT)(2: -)(3: 4:00)"), localTimeZoneName, timeZoneDiff != 0 ? (timeZoneDiff < 0 ? "-" : "+") : "", diffString)
    }
    
    func cancelDelete() {
        showingDeleteConfirmation = false
    }
    
    var deliveryStatus: some View {
        // podOK is true at this point. Thus there will be a basalDeliveryState
        VStack(alignment: .leading, spacing: 5) {
            Text(LocalizedString("Insulin Delivery", comment: "Title of insulin delivery section"))
                .foregroundColor(Color(UIColor.secondaryLabel))
            if let rate = self.viewModel.basalDeliveryRate {
                HStack(alignment: .center) {
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(self.viewModel.basalRateFormatter.string(from: rate) ?? "")
                            .font(.system(size: 28))
                            .fontWeight(.heavy)
                            .fixedSize()
                        Text(LocalizedString("U/hr", comment: "Units for showing temp basal rate")).foregroundColor(.secondary)
                    }
                }
            } else {
                HStack(alignment: .center) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(guidanceColors.warning)
                    Text(LocalizedString("Insulin\nSuspended", comment: "Label for insulin suspended"))
                        .font(.system(size: 14))
                        .fontWeight(.heavy)
                        .fixedSize()
                }
            }
        }
    }
    
    func reservoir(filledPercent: CGFloat, fillColor: Color) -> some View {
        ZStack(alignment: Alignment(horizontal: .center, vertical: .center)) {
            GeometryReader { geometry in
                let offset = geometry.size.height * 0.05
                let fillHeight = geometry.size.height * 0.81
                Rectangle()
                    .fill(fillColor)
                    .mask(
                        Image(frameworkImage: "pod_reservoir_mask_swiftui")
                            .resizable()
                            .scaledToFit()
                    )
                    .mask(
                        Rectangle().path(in: CGRect(x: 0, y: offset + fillHeight - fillHeight * filledPercent, width: geometry.size.width, height: fillHeight * filledPercent))
                    )
            }
            Image(frameworkImage: "pod_reservoir_swiftui")
                .renderingMode(.template)
                .resizable()
                .foregroundColor(fillColor)
                .scaledToFit()
        }.frame(width: 23, height: 32)
    }

    
    var reservoirStatus: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text(LocalizedString("Insulin Remaining", comment: "Header for insulin remaining on pod settings screen"))
                .foregroundColor(Color(UIColor.secondaryLabel))
            HStack {
                if let reservoirLevel = viewModel.reservoirLevel {
                    reservoir(filledPercent: CGFloat(reservoirLevel.percentage), fillColor: reservoirColor(for: reservoirLevel))
                    Text(viewModel.reservoirText(for: reservoirLevel))
                        .font(.system(size: 28))
                        .fontWeight(.heavy)
                        .fixedSize()
                } else {
                    Image(systemName: "x.circle.fill")
                        .foregroundColor(Color(UIColor.secondaryLabel))
                    
                    Text(LocalizedString("No Pod", comment: "Text shown in insulin remaining space when no pod is paired")).fontWeight(.bold)
                }
                    
            }
        }
    }
    
    func suspendResumeButtonColor(for basalDeliveryState: PumpManagerStatus.BasalDeliveryState) -> Color {
        switch basalDeliveryState {
        case .active, .tempBasal, .cancelingTempBasal, .initiatingTempBasal:
            return .accentColor
        case .suspending, .resuming:
            return Color.secondary
        case .suspended:
            return guidanceColors.warning
        }
    }
    
    var suspendResumeRow: some View {
        // podOK is true at this point. Thus there will be a basalDeliveryState
        HStack {
            if let basalState = self.viewModel.basalDeliveryState {
                Button(action: {
                    self.suspendResumeTapped()
                }) {
                    HStack {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 22))
                            .accentColor(suspendResumeButtonColor(for: basalState))
                        Text(basalState.suspendResumeActionText)
                            .foregroundColor(basalState.suspendResumeActionColor)
                    }
                }
                .actionSheet(isPresented: $showSuspendOptions) {
                    suspendOptionsActionSheet
                }
                Spacer()
                if self.viewModel.basalDeliveryState!.transitioning {
                    ActivityIndicator(isAnimating: .constant(true), style: .medium)
                }
            }
        }
    }
    
    private var doneButton: some View {
        Button("Done", action: {
            self.viewModel.doneTapped()
        })
    }
    
    var headerImage: some View {
        VStack(alignment: .center) {
            Image(frameworkImage: "Pod")
                .resizable()
                .aspectRatio(contentMode: ContentMode.fit)
                .frame(height: 100)
                .padding([.top,.horizontal])
        }.frame(maxWidth: .infinity)
    }
        
    var body: some View {
        List {
            VStack(alignment: .leading) {
                headerImage

                lifecycleProgress

                if self.viewModel.podOk {
                    HStack(alignment: .top) {
                        deliveryStatus
                        Spacer()
                        reservoirStatus
                    }
                }
                
            }.padding(.bottom, 8)
            
            if self.viewModel.podOk {
                Section(header: Text(LocalizedString("Activity", comment: "Section header for activity section")).font(.headline).foregroundColor(Color.primary)) {
                    suspendResumeRow
                    if case .suspended(let suspendDate) = self.viewModel.basalDeliveryState {
                        HStack {
                            Text(LocalizedString("Suspended At", comment: "Label for suspended at time"))
                            Spacer()
                            Text(self.viewModel.timeFormatter.string(from: suspendDate))
                                .foregroundColor(Color.secondary)
                        }
                    }
                }

                if let activatedAt = self.viewModel.activatedAt, let podVersion = self.viewModel.podVersion {
                    Section() {
                        HStack {
                            Text(LocalizedString("Pod Insertion", comment: "Label for pod insertion row"))
                            Spacer()
                            Text(self.viewModel.dateFormatter.string(from: activatedAt))
                                .foregroundColor(Color.secondary)
                        }
                        
                        HStack {
                            Text(LocalizedString("Pod Expiration", comment: "Label for pod expiration row"))
                            Spacer()
                            Text(self.viewModel.dateFormatter.string(from: activatedAt + Pod.nominalPodLife))
                                .foregroundColor(Color.secondary)
                        }
                        
//                        NavigationLink(destination: PodDetailsView(podVersion: podVersion)) {
//                            FrameworkLocalText("Pod Details", comment: "Text for pod details disclosure row").foregroundColor(Color.primary)
//                        }
                    }
                }
            }
            
            Section() {
                Button(action: {
                    print("Navigate to \(self.viewModel.lifeState.nextPodLifecycleAction)")
                }) {
                    Text(self.viewModel.lifeState.nextPodLifecycleActionDescription)
                        .foregroundColor(self.viewModel.lifeState.nextPodLifecycleActionColor)
                }
            }

            Section(header: Text(LocalizedString("Configuration", comment: "Section header for configuration section")).font(.headline).foregroundColor(Color.primary)) {
                HStack {
                    if self.viewModel.timeZone != TimeZone.currentFixed {
                        Button(action: {
                            self.viewModel.changeTimeZoneTapped()
                        }) {
                            Text(LocalizedString("Change Time Zone", comment: "The title of the command to change pump time zone"))
                        }
                    } else {
                        Text(LocalizedString("Schedule Time Zone", comment: "Label for row showing pump time zone"))
                    }
                    Spacer()
                    Text(timeZoneString)
                }

            }

            if self.viewModel.lifeState.allowsPumpManagerRemoval {
                Section() {
                    Button(action: {
                        self.showingDeleteConfirmation = true
                    }) {
                        Text(LocalizedString("Switch to other insulin delivery device", comment: "Label for PumpManager deletion button"))
                            .foregroundColor(guidanceColors.critical)
                    }
                    .actionSheet(isPresented: $showingDeleteConfirmation) {
                        removePumpManagerActionSheet
                    }
                }
            }

            Section(header: Text(LocalizedString("Support", comment: "Label for support disclosure row")).font(.headline).foregroundColor(Color.primary)) {
                NavigationLink(destination: EmptyView()) {
                    // Placeholder
                    Text("Get Help with Omnipod 5").foregroundColor(Color.primary)
                }
            }

        }
        .alert(isPresented: $viewModel.alertIsPresented, content: { alert(for: viewModel.activeAlert!) })
        .insetGroupedListStyle()
        .navigationBarItems(trailing: doneButton)
        .navigationBarTitle(self.viewModel.viewTitle)
        
    }
    
    var removePumpManagerActionSheet: ActionSheet {
        ActionSheet(title: Text(LocalizedString("Remove Pump", comment: "Title for Omnipod PumpManager deletion action sheet.")), message: Text(LocalizedString("Are you sure you want to stop using Omnipod?", comment: "Message for Omnipod PumpManager deletion action sheet")), buttons: [
            .destructive(Text(LocalizedString("Delete Omnipod", comment: "Button text to confirm Omnipod PumpManager deletion"))) {
                self.viewModel.stopUsingOmnipodTapped()
            },
            .cancel()
        ])
    }

    var suspendOptionsActionSheet: ActionSheet {
        ActionSheet(
            title: Text(LocalizedString("Delivery Suspension Reminder", comment: "Title for suspend duration selection action sheet")),
            message: Text(LocalizedString("How long would you like to suspend insulin delivery?", comment: "Message for suspend duration selection action sheet")),
            buttons: [
                .default(Text(LocalizedString("30 minutes", comment: "Button text for 30 minute suspend duration")), action: { self.viewModel.suspendDelivery(duration: .minutes(30)) }),
                .default(Text(LocalizedString("1 hour", comment: "Button text for 1 hour suspend duration")), action: { self.viewModel.suspendDelivery(duration: .hours(1)) }),
                .default(Text(LocalizedString("1 hour 30 minutes", comment: "Button text for 1 hour 30 minute suspend duration")), action: { self.viewModel.suspendDelivery(duration: .hours(1.5)) }),
                .default(Text(LocalizedString("2 hours", comment: "Button text for 2 hour suspend duration")), action: { self.viewModel.suspendDelivery(duration: .hours(2)) }),
                .cancel()
            ])
    }

    func suspendResumeTapped() {
        switch self.viewModel.basalDeliveryState {
        case .active, .tempBasal:
            showSuspendOptions = true
        case .suspended:
            self.viewModel.resumeDelivery()
        default:
            break
        }
    }
    
    private func alert(for alert: PodSettingsViewAlert) -> SwiftUI.Alert {
        switch alert {
        case .suspendError(let error):
            return SwiftUI.Alert(
                title: Text("Failed to Suspend Insulin Delivery", comment: "Alert title for suspend error"),
                message: Text(error.localizedDescription)
            )

        case .resumeError(let error):
            return SwiftUI.Alert(
                title: Text("Failed to Resume Insulin Delivery", comment: "Alert title for resume error"),
                message: Text(error.localizedDescription)
            )
        }
    }
    
    func reservoirColor(for level: ReservoirLevel) -> Color {
        switch level {
        case .aboveThreshold:
            return insulinTintColor
        case .valid(let value):
            if value > 10 {
                return insulinTintColor
            } else {
                return guidanceColors.warning
            }
        }
    }
}

struct DashSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        DashSettingsSheetView()
    }
}


struct DashSettingsSheetView: View {
    
    @State var showingDetail = true
    
    var body: some View {
        VStack {
            Button(action: {
                self.showingDetail.toggle()
            }) {
                Text("Show Detail")
            }.sheet(isPresented: $showingDetail) {
                NavigationView {
                    ZStack {
                        PodSettingsView(viewModel: previewModel())
                    }
                }
            }
            HStack {
                Spacer()
            }
            Spacer()
        }
        .background(Color.green)
    }
    
    func previewModel() -> PodSettingsViewModel {
        let schedule = BasalSchedule(entries: [BasalScheduleEntry(rate: 1, startTime: 0)])
        let podState = PodState(address: 0x1234, piVersion: "1.1", pmVersion: "2.2", lot: 0x1234, tid: 0x1234, insulinType: .novolog)
        let state = OmnipodPumpManagerState(podState: podState, timeZone: .currentFixed, basalSchedule: schedule, rileyLinkConnectionManagerState: nil, insulinType: .novolog)
        let pumpManager = OmnipodPumpManager(state: state, rileyLinkDeviceProvider: MockRileyLinkProvider())
        let model = PodSettingsViewModel(pumpManager: pumpManager)
        model.basalDeliveryState = .active(Date())
        model.lifeState = .timeRemaining(.days(2.5))
        return model
    }
}

class MockRileyLinkProvider: RileyLinkDeviceProvider {
    func getDevices(_ completion: @escaping ([RileyLinkDevice]) -> Void) {
        completion([])
    }
    
    var idleListeningEnabled = false
    
    var timerTickEnabled = false
    
    func deprioritize(_ device: RileyLinkDevice, completion: (() -> Void)?) {
        completion?()
    }
    
    func assertIdleListening(forcingRestart: Bool) {
    }
    
    var idleListeningState: RileyLinkDevice.IdleListeningState = .disabled
    
    var debugDescription = "Blah"
}
