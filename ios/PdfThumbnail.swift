import PDFKit

@objc(PdfThumbnail)
class PdfThumbnail: NSObject {

    @objc
    static func requiresMainQueueSetup() -> Bool {
        return false
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func getOutputFilename(outputFileName: String, page: Int) -> String {
        let components = outputFileName.components(separatedBy: "/")
        var prefix: String
        if let origionalFileName = components.last {
            prefix = origionalFileName.replacingOccurrences(of: ".", with: "-")
        } else {
            prefix = "pdf"
        }
        let random = Int.random(in: 0 ..< Int.max)
        return "\(prefix)-thumbnail-\(page)-\(random).jpg"
    }

    func generatePage(pdfPage: PDFPage, outputFileName: String, page: Int) -> Dictionary<String, Any>? {
        /// Define destination path for the final JPEG image relative to the Documents directory.
        let outputFile = getDocumentsDirectory().appendingPathComponent(getOutputFilename(outputFileName: outputFileName, page: page))
        
        /// Bounds for capturing the JPEG image, in this case, the entire bounds of the media of the PDF page.
        let pageRect = pdfPage.bounds(for: .mediaBox)
        
        /// Configuration for the UIGraphicsImageRenderer, which grants us a finer level of control over the graphics generation.
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        
        /// Begin a rendering context with the size of the PDF page and the scale of our display to ensure it shows at the ideal resolution.
        let renderer = UIGraphicsImageRenderer(size: pageRect.size, format: format)
        let image = renderer.image { ctx in
            /// Align the PDF based on the default CGContext origin placement (move to top-left instead of starting off on center point).
            ctx.cgContext.translateBy(x: -pageRect.origin.x, y: pageRect.size.height - pageRect.origin.y)
            
            /// Flip the context as CGContext begin counting from bottom instead of top.
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            
            /// Draw the full media box of the PDF page at full resolution onto the current CGContext.
            pdfPage.draw(with: .mediaBox, to: ctx.cgContext)
        }
        
        /// Safeguard to ensure we were able to convert the UIImage into valid JPEG Data (1.0 = no compression).
        guard let data = image.jpegData(compressionQuality: 1.0) else {
            return nil
        }
        
        do {
            /// Write high resolution JPEG data to outputFile path, the image size should match the pageRect.
            try data.write(to: outputFile)

            /// Output dimensions of the final image and the local Image URI we generated using the Documents directory and getOutputFilename().
            return [
                "uri": outputFile.absoluteString,
                "width": Int(pageRect.width),
                "height": Int(pageRect.height),
            ]
        } catch {
            return nil
        }
    }
    
    @available(iOS 11.0, *)
    @objc(generate:withPage:withResolver:withRejecter:)
    func generate(filePath: String, page: Int, resolve:RCTPromiseResolveBlock, reject:RCTPromiseRejectBlock) -> Void {
        guard let fileUrl = URL(string: filePath) else {
            reject("FILE_NOT_FOUND", "File \(filePath) not found", nil)
            return
        }
        guard let pdfDocument = PDFDocument(url: fileUrl) else {
            reject("FILE_NOT_FOUND", "File \(filePath) not found", nil)
            return
        }
        guard let pdfPage = pdfDocument.page(at: page) else {
            reject("INVALID_PAGE", "Page number \(page) is invalid, file has \(pdfDocument.pageCount) pages", nil)
            return
        }

        if let pageResult = generatePage(pdfPage: pdfPage, outputFileName: "fion-geopdf", page: page) {
            resolve(pageResult)
        } else {
            reject("INTERNAL_ERROR", "Cannot write image data", nil)
        }
    }
}
