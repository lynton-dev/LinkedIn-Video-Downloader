//
//  ContentView.swift
//  LinkedIn Video Downloader
//
//  Created by Lynton Schoeman on 2022-02-28.
//

import SwiftUI
import SwiftSoup

struct ContentView: View {
    @State private var linkedInURL: String = ""
    @State private var progressShown = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack {
            HStack {
                TextField("Enter LinkedIn Post URL", text: $linkedInURL)

                Button {
                    let pasteboard = NSPasteboard.general
                    if let str = pasteboard.string(forType: NSPasteboard.PasteboardType.string) {
                        // text found
                        self.linkedInURL = str
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard.fill")
                }.help("Paste")
            }.padding()
            
            Button("Download Video") {
                // Get URL to LinkedIn video
                let video = self.getLinkedInVideoUrlString(urlString: linkedInURL)
                if (video != nil) {
                    let videoURLString = video?.URLString ?? ""
                    let videoFileExt = video?.fileExt ?? ""
                    // Download video
                    if (!(videoURLString.isEmpty)) {
                        if (videoFileExt.isEmpty) {
                            self.downloadVideoLinkAndCreateAsset(videoLink: videoURLString)
                        } else {
                            self.downloadVideoLinkAndCreateAsset(videoLink: videoURLString, outputFileExt: videoFileExt)
                        }
                        self.progressShown = true
                    }
                }
            }
            
            ProgressView()
                .frame(height: self.progressShown ? nil : 0)
                .opacity(self.progressShown ? 1 : 0)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Oops!"),
                message: Text(self.alertMessage),
                dismissButton: .cancel(Text("Okay"), action: {
                    
                })
            )
        }
        .padding()
    }
    
    func getLinkedInVideoUrlString(urlString : String) -> Video? {
        // Initial URL checking and/or corrections
        var inputURLStr = urlString
        if (!inputURLStr.hasPrefix("http")) {
            if (!inputURLStr.hasPrefix("www.")) {
                inputURLStr = "www." + inputURLStr
            }
            inputURLStr = "https://" + inputURLStr
        } else if (inputURLStr.hasPrefix("https://")) {
            inputURLStr = inputURLStr.replacingOccurrences(of: "https://", with: "https://www.")
        }
        
        // Update the text field with the corrected URL
        self.linkedInURL = inputURLStr
        
        if (!inputURLStr.hasPrefix("https://www.linkedin.com/")) {
            self.alertMessage = "Not a valid LinkedIn URL."
            self.showAlert.toggle()
            return nil
        }
        
        guard let inputURL = URL(string: inputURLStr) else {
            print("Error: \(inputURLStr) doesn't seem to be a valid URL")
            self.alertMessage = "Not a valid URL."
            self.showAlert.toggle()
            return nil
        }

        do {
            let HTMLString = try String(contentsOf: inputURL, encoding: .utf8)
            
            let doc: Document = try SwiftSoup.parse(HTMLString)
            let videoElements: Elements = try doc.select("video")
            if (videoElements.count == 0) {
                self.alertMessage = "No embedded video found in the LinkedIn post."
                self.showAlert.toggle()
                return nil
            }
            let videoElement: Element = videoElements.first()!   // video tag ie. <video...
            var videoDataSources = try videoElement.attr("data-sources")   // data-sources attribute in video tag
            videoDataSources = try Entities.unescape(videoDataSources)  // unescape HTML text
            //print(videoDataSources)
            
            let httpCount = videoDataSources.components(separatedBy:"http").count - 1
            //print ("httpCount: " + String(httpCount))
            
            var videosList = [Video]()
            
            for _ in 0...httpCount - 1 {
                // Get video URL
                let videoURLStartRange = videoDataSources.range(of: "http")         // Get start range starting with "http"
                var videoURL = videoDataSources[videoURLStartRange!.lowerBound...]  // Set videoURL as a substring of the start range forward
                let videoURLEndRange = videoURL.firstIndex(of: "\"")!               // Get end range that is the first index of "
                videoURL = videoURL[..<videoURLEndRange]                            // This gives us the final video URL
                
                let videoURLString = String(videoURL)
                print(videoURLString)
                
                // Get video quality components from video URL
                let videoURLcomponents = videoURLString.components(separatedBy: "/")
                var videoQuality = ""
                for component in videoURLcomponents {
                    // Check known substrings of video quality URL component
                    if (component.contains("mp4") || component.contains("fp") || component.contains("crf")) {
                        // Video quality component found
                        videoQuality = component
                        break
                    }
                }
                //print(videoQuality)
                
                var fileExt = "mp4"
                var res = 0
                var framerate = 0
                
                // Extract needed video info
                if (!videoQuality.isEmpty) {
                    let videoQualityURLcomponents = videoQuality.components(separatedBy: "-")
                    fileExt = videoQualityURLcomponents[0]
                    for part in videoQualityURLcomponents {
                        if (part.hasSuffix("fp")) {
                            let framerateStr = videoQualityURLcomponents[2].replacingOccurrences(of: "fp", with: "")
                            if (framerateStr.isNumeric) {
                                framerate = Int(framerateStr) ?? 0
                            }
                        } else if (part.last == "p") {
                            let resStr = videoQualityURLcomponents[1].replacingOccurrences(of: "p", with: "")
                            if (resStr.isNumeric) {
                                res = Int(resStr) ?? 0
                            }
                        }
                    }
                    //print (fileExt + ", " + String(res) + ", " + String(framerate))
                }
                videosList.append(Video(URLString: videoURLString, fileExt: fileExt, res: res, framerate: framerate))
                
                // Remove this video URL from videoDataSources string
                videoDataSources = videoDataSources.replacingOccurrences(of: videoURLString, with: "")
            }
            
            // Sort videosList by resolution
            videosList.sort { (lhs: Video, rhs: Video) -> Bool in
                return lhs.res < rhs.res
            }
            
            // The last element in videosList will have the highest resolution. We will use this video.
            let video = videosList.last
            return video
            
        } catch let error {
            print("Error: \(error)")
            self.alertMessage = "Something went wrong."
            self.showAlert.toggle()
        }
        
        return nil
    }
    
    func downloadVideoLinkAndCreateAsset(videoLink: String, outputFileExt: String = "mp4") {
        // use guard to make sure you have a valid url
        guard let videoURL = URL(string: videoLink) else { return }

        guard let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        var suggestedFileName = "linkedin_video_" + String(Date().timeIntervalSince1970.rounded()) + "." + outputFileExt
        var destinationURL = documentsDirectoryURL.appendingPathComponent(suggestedFileName)

        // check if the file already exist at the destination folder if you don't want to download it twice
        if !FileManager.default.fileExists(atPath: documentsDirectoryURL.appendingPathComponent(videoURL.lastPathComponent).path) {

            // set up your download task
            URLSession.shared.downloadTask(with: videoURL) { (location, response, error) -> Void in

                // use guard to unwrap your optional url
                guard let location = location else { return }
                
                suggestedFileName = response?.suggestedFilename ?? videoURL.lastPathComponent

                // create a destination url with the server response suggested file name
                destinationURL = documentsDirectoryURL.appendingPathComponent(suggestedFileName)

                do {

                    try FileManager.default.moveItem(at: location, to: destinationURL)

                } catch { print(error) }

            }.resume()

        } else {
            print("File already exists at destination url")
        }
        
        // Show save dialog. This will move the video file from the sandboxed destinationURL to a folder of the users choice.
        DispatchQueue.main.async {      // NSSavePanel has to be on the main thread
            @Binding var progressShown : Bool
            let savePanel = NSSavePanel()
            savePanel.canCreateDirectories = true
            savePanel.showsTagField = false
            savePanel.nameFieldStringValue = suggestedFileName
            savePanel.level = .modalPanel
            savePanel.begin {
                if $0 == .OK {
                    do {
                        guard let saveURL = savePanel.url else { return }
                        try FileManager.default.moveItem(at: destinationURL, to: saveURL)
                        self.progressShown = false
                    } catch {
                        print(error)
                        self.progressShown = false
                    }
                }
                else {
                    // Save has been cancelled. Delete temp video file.
                    do {
                        try FileManager.default.removeItem(at: destinationURL)
                    } catch {
                        print(error)
                    }
                    self.progressShown = false
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct Video {
    var URLString : String
    var fileExt : String
    var res : Int
    var framerate : Int
}

extension String {
    var isNumeric : Bool {
        return Double(self) != nil
    }
}
