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
    
    var body: some View {
        VStack {
            HStack {
                TextField("Enter LinkedIn Post URL", text: $linkedInURL)

                Button {
                    let pasteboard = NSPasteboard.general
                    if let str = pasteboard.string(forType: NSPasteboard.PasteboardType.string) {
                        // text found
                        linkedInURL = str
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard.fill")
                }.help("Paste")
            }
            
            Button("Download") {
                let videoURLString = getLinkedInVideoUrlString(urlString: linkedInURL)
                if (!videoURLString.isEmpty) {
                    downloadVideoLinkAndCreateAsset(videoURLString)
                    progressShown = true
                }
            }
            
            ProgressView()
                .frame(height: progressShown ? nil : 0)
                .opacity(progressShown ? 1 : 0)
        }
            .padding()
    }
    
    func downloadVideoLinkAndCreateAsset(_ videoLink: String) {
        // use guard to make sure you have a valid url
        guard let videoURL = URL(string: videoLink) else { return }

        guard let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        var suggestedFileName = "video.mp4"
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

func getLinkedInVideoUrlString(urlString : String) -> String {
    guard let myURL = URL(string: urlString) else {
        print("Error: \(urlString) doesn't seem to be a valid URL")
        return ""
    }

    do {
        let HTMLString = try String(contentsOf: myURL, encoding: .utf8)
        
        //let doc: Document = try SwiftSoup.parse(myHTMLString)
        //let str = try doc.text()
        
        let doc: Document = try SwiftSoup.parse(HTMLString)
        let video: Element = try doc.select("video").first()!   // video tag ie. <video...
        var videoDataSources = try video.attr("data-sources")   // data-sources attribute in video tag
        videoDataSources = try Entities.unescape(videoDataSources)  // unescape HTML text
        //print(videoDataSources)
        
        let httpCount = videoDataSources.components(separatedBy:"http").count - 1
        //print ("httpCount: " + String(httpCount))
        
        if (httpCount >= 1) {
            // Get low quality video URL
            var videoURLStartRange = videoDataSources.range(of: "http")         // Get start range starting with "http"
            var videoURL = videoDataSources[videoURLStartRange!.lowerBound...]  // Set videoURL as a substring of the start range forward
            var videoURLEndRange = videoURL.firstIndex(of: "\"")!               // Get end range that is the first index of "
            videoURL = videoURL[..<videoURLEndRange]                            // This gives us the final video URL
            
            let lowQualityVideoURLString = String(videoURL)
            print(lowQualityVideoURLString)
            
            var lowVideoQuality = String(lowQualityVideoURLString[lowQualityVideoURLString.range(of: "mp4")!.lowerBound...])
            lowVideoQuality = String(lowVideoQuality[..<lowVideoQuality.range(of: "fp")!.upperBound])
            //print(lowVideoQuality)
            
            var videoContentURLString = lowQualityVideoURLString
            
            if (httpCount >= 2) {
                // Remove low quality video URL from videoDataSources string to leave remaining high quality video URL
                videoDataSources = videoDataSources.replacingOccurrences(of: lowQualityVideoURLString, with: "")
                
                // Get high quality video URL
                videoURLStartRange = videoDataSources.range(of: "http")
                videoURL = videoDataSources[videoURLStartRange!.lowerBound...]
                videoURLEndRange = videoURL.firstIndex(of: "\"")!
                videoURL = videoURL[..<videoURLEndRange]
                
                let highQualityVideoURLString = String(videoURL)
                print(highQualityVideoURLString)
                
                var highVideoQuality = String(highQualityVideoURLString[highQualityVideoURLString.range(of: "mp4")!.lowerBound...])
                highVideoQuality = String(highVideoQuality[..<highVideoQuality.range(of: "fp")!.upperBound])
                //print(highVideoQuality)
                
                videoContentURLString = highQualityVideoURLString
            }
            
            return videoContentURLString
        }
        
    } catch let error {
        print("Error: \(error)")
    }
    
    return ""
}
