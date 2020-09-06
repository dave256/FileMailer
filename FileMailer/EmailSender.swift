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


    /// for each subdirectory in directory, attach one file and email to the email address specified by subdirectory name
    /// - Parameters:
    ///   - emailSender: email account to use to send (must be a valid account in Mail app)
    ///   - directory: URL of directory containing all the subdirectories that are email address names
    func sendEmails() {
        DispatchQueue.global().async {
            let fm = FileManager()
            let url = URL(fileURLWithPath: self.directory)
            if let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]) {
                for content in contents {
                    if let v = try? content.resourceValues(forKeys: [.isDirectoryKey]) {
                        if let isDir = v.isDirectory, isDir {
                            let directoryContents = try? fm.contentsOfDirectory(at: content, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants, .skipsPackageDescendants])
                            if let firstURL = directoryContents?.first {
                                let emailRecipient = content.lastPathComponent
                                let script = self.createAppleScript(emailSender: self.emailSender, subject: self.subject, emailRecipient: emailRecipient, fileURL: firstURL)

                                // execute AppleScript on main queue
                                DispatchQueue.main.sync {
                                    self.executeScript(script)
                                    let msg = self.executeScript(script)
                                    if msg != "true" {
                                        print(emailRecipient, terminator: " ")
                                        print(msg)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

    }

    /// create AppleScript command to email one file as an attachment
    /// - Parameters:
    ///   - sender: email account to use to send (must be a valid account in Mail app)
    ///   - recipient: email address of the recipient
    ///   - fileURL: URL of file to send
    /// - Returns: String containing AppleScript command that when executed will send the email
    private func createAppleScript(emailSender: String, subject: String, emailRecipient: String, fileURL: URL) -> String {

        let script = """
        set p to "\(fileURL.path)"
        set theAttachment to POSIX file p

        tell application "Mail"
            set theNewMessage to make new outgoing message with properties {subject:"\(subject)", sender:"\(emailSender)", content:"See attached.\n\n", visible:true}

            tell theNewMessage
                make new to recipient at end of to recipients with properties {address:"\(emailRecipient)"}
            end tell
            tell content of theNewMessage
                try
                    make new attachment with properties {file name:theAttachment} at after the last word of the last paragraph
                    set message_attachment to 0
                on error errmess -- oops
                    log errmess -- log the error
                    set message_attachment to 1
                end try
                log "message_attachment = " & message_attachment
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