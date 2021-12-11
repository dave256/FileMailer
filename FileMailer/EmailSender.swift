//
//  EmailSender.swift
//  FileMailer
//
//  Created by David M Reed on 9/6/20.
//  Copyright © 2020 David M Reed. All rights reserved.
//

import Foundation

struct EmailSender {

    var emailSender: String
    var subject: String 
    var directory: String
    var fileExtension: String


    /// for each subdirectory in directory, attach one file and email to the email address specified by subdirectory name
    /// - Parameters:
    ///   - emailSender: email account to use to send (must be a valid account in Mail app)
    ///   - directory: URL of directory containing all the subdirectories that are email address names
    func sendEmails() async {
            let fm = FileManager()
            let url = URL(fileURLWithPath: self.directory)
            if let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]) {
                let sortedContents = contents.sorted() {
                    $0.path < $1.path
                }
                for content in sortedContents {
                    if let v = try? content.resourceValues(forKeys: [.isDirectoryKey]) {
                        if let isDir = v.isDirectory, isDir {
                            if let directoryContents = try? fm.contentsOfDirectory(at: content, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants, .skipsPackageDescendants]) {
                                let urls: [URL]
                                if !self.fileExtension.isEmpty {
                                    urls = directoryContents.filter() { $0.pathExtension == self.fileExtension }
                                } else {
                                    urls = directoryContents
                                }
                                if urls.count > 0 {
                                    let emailRecipient = content.lastPathComponent
                                    let script = self.createAppleScript(emailSender: self.emailSender, subject: self.subject, emailRecipient: emailRecipient, attachmentURLs: urls)
                                    // execute AppleScript on main queue
                                    await MainActor.run {
                                        let msg = self.executeScript(script)
                                        if msg != "true" {
                                            print(emailRecipient, terminator: " ")
                                            print(msg)
                                        }
                                    }
                                    // wait 10 seconds to give time to send before starting next message
                                    do {
                                        try await Task.sleep(nanoseconds: 10 * 1_000_000_000)
                                    }
                                    catch {
                                        print("Task.sleep threw")
                                    }
                                }
                            }
                        }
                    }
                }
            }
    }

    /// create AppleScript to send email to recipient with attached files
    /// - Parameters:
    ///   - emailSender: sender address to use (must be a valid email account for user)
    ///   - subject: email subject to use
    ///   - emailRecipient: email address of the recipient
    ///   - urls: urls to attach
    /// - Returns: string containing the AppleScript commands
    private func createAppleScript(emailSender: String, subject: String, emailRecipient: String, attachmentURLs urls: [URL]) -> String {

        var script = ""
        for (index, url) in urls.enumerated() {
            script += """

            set p\(index) to "\(url.path)"
            set theAttachment\(index) to POSIX file p\(index)
        """
        }
        script += """

        tell application "Mail"
            set theNewMessage to make new outgoing message with properties {subject:"\(subject)", sender:"\(emailSender)", content:"See attached.\n\n", visible:true}

            tell theNewMessage
                make new to recipient at end of to recipients with properties {address:"\(emailRecipient)"}
            end tell
            tell content of theNewMessage
        """

        for index in 0..<urls.count {
            let attachCommand = """

                try
                    make new attachment with properties {file name:theAttachment\(index)} at after the last word of the last paragraph
                    set message_attachment to 0
                on error errmess -- oops
                    log errmess -- log the error
                    set message_attachment to 1
                end try
                log "message_attachment = " & message_attachment
        """
            script += attachCommand
        }
        script += """

            end tell
            delay 5
            tell theNewMessage
                send
            end tell
        end tell
        """

        return script
    }

    @discardableResult
    private func executeScript(_ script: String) -> String {
        var msg = ""

        // execute the AppleScript
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let output = scriptObject.executeAndReturnError(&error)
            if error != nil {
                msg = "error: \(error!)"
            }
            else if let s = output.stringValue {
                msg = s
            }
        }
        return msg
    }
}
