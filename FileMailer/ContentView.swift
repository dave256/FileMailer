//
//  ContentView.swift
//  FileMailer
//
//  Created by David M Reed on 9/6/20.
//  Copyright © 2020 David M Reed. All rights reserved.
//

import SwiftUI

struct CustomAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat {
        return context[.leading]
    }
}

extension HorizontalAlignment {
    static let custom: HorizontalAlignment = HorizontalAlignment(CustomAlignment.self)
}

struct DefaultValues {
    @UserDefaultsBacked(key: "defaultSender", defaultValue: "") static var defaultSender: String
    @UserDefaultsBacked(key: "defaultExtension", defaultValue: "") static var defaultExtension: String
}

struct ContentView: View {

    @State private var emailSender: String = ""
    @State private var emailSubject: String = ""
    @State private var fileExtension: String = ""
    @State private var folder: String = ""
    @State private var showingFolderBlankAlert = false
    @State private var sendDisabled = false

    var body: some View {
        VStack {
            Text("Email each address in the folder and attach the file in its folder that matches extension")
            Spacer()
            VStack(alignment: .custom) {
                HStack {
                    Text("Sending address:").fixedSize().frame(width: 120, alignment: .leading)
                    TextField("", text: $emailSender).alignmentGuide(.custom) { $0[.leading] }
                }
                HStack {
                    Text("Email subject:").fixedSize().frame(width: 120, alignment: .leading)
                    TextField("", text: $emailSubject).alignmentGuide(.custom) { $0[.leading] }
                }
                HStack {
                    Text("Folder:").fixedSize().frame(width: 120, alignment: .leading)
                    TextField("", text: $folder).alignmentGuide(.custom) { $0[.leading] }
                }
                HStack {
                    Text("Extension:").fixedSize().frame(width: 120, alignment: .leading)
                    TextField("", text: $fileExtension).alignmentGuide(.custom) { $0[.leading] }
                }
            }
            .alert(isPresented: $showingFolderBlankAlert) {
                Alert(title: Text("Folder blank"), message: Text("Must specifiy a folder contain the email addresses as folders"), dismissButton: .default(Text("Ok")))
            }
            Spacer()
            Button("Send") {
                if self.emailSender != "" {
                    DefaultValues.defaultSender = self.emailSender
                }
                if self.fileExtension != "" {
                    DefaultValues.defaultExtension = self.fileExtension
                }
                UserDefaults.standard.synchronize()


                guard self.folder != "" else {
                    self.showingFolderBlankAlert = true
                    return
                }

                // disable send button until all emails send
                sendDisabled = true

                let subject = self.emailSubject != "" ? self.emailSubject : "File attached"
                let sender = EmailSender(emailSender: self.emailSender, subject: subject, directory: self.folder, fileExtension: self.fileExtension)
                Task {
                    await sender.sendEmails()
                    await MainActor.run {
                        sendDisabled = false
                    }
                }
            }
            .disabled(sendDisabled)
            Spacer()
        }
        .padding()
        .frame(minWidth: 300, idealWidth: 500, maxWidth: 800, minHeight: 300, idealHeight: 600, maxHeight: 600, alignment: .center)
        .onDrop(of: ["public.file-url"], isTargeted: nil) { (items) -> Bool in
            guard items.count > 0 else {
                return false
            }
            if let item = items.first {
                guard item.hasItemConformingToTypeIdentifier("public.file-url") else {
                    return false
                }
                item.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
                    if let urlData = urlData as? Data {
                        if let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                            self.folder = url.path
                        }
                    }

                }
            }
            return true
        }.onAppear() {
            if self.emailSender == "" {
                self.emailSender = DefaultValues.defaultSender
            }
            if self.fileExtension == "" {
                self.fileExtension = DefaultValues.defaultExtension
            }
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
