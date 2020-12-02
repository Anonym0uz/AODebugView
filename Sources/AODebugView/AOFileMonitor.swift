//
//  AOFileMonitor.swift
//  AOFileMonitor
//
//  Created by Alexander Orlov on 02.12.2020.
//  Copyright © 2020 Alexander Orlov. All rights reserved.
//
// Huge thanks Bruno Rocha (https://github.com/rockbruno) for DispatchSource tutorial (https://medium.com/better-programming/dispatchsource-detecting-changes-in-files-and-folders-in-swift-5486c4363e08)

import UIKit

protocol AOFileMonitorDelegate: AnyObject {
    func didReceive(changes: String)
}

class AOFileMonitor {
    
    let url: URL

    let fileHandle: FileHandle
    let source: DispatchSourceFileSystemObject

    weak var delegate: AOFileMonitorDelegate?

    init(url: URL) throws {
        self.url = url
        self.fileHandle = try FileHandle(forReadingFrom: url)

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileHandle.fileDescriptor,
            eventMask: .extend,
            queue: DispatchQueue.main
        )

        source.setEventHandler {
            let event = self.source.data
            self.process(event: event)
        }

        source.setCancelHandler {
            if #available(iOS 13.0, *) {
                try? self.fileHandle.close()
            } else {
                self.fileHandle.closeFile()
            }
        }

        fileHandle.seekToEndOfFile()
        source.resume()
    }

    deinit {
        source.cancel()
    }

    func process(event: DispatchSource.FileSystemEvent) {
        guard event.contains(.extend) else {
            return
        }
        let newData = self.fileHandle.readDataToEndOfFile()
        let string = String(data: newData, encoding: .utf8)!
        self.delegate?.didReceive(changes: string)
    }
}
