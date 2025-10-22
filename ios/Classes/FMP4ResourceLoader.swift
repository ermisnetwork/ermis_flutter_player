import Foundation
import AVFoundation
import MobileCoreServices

class FMP4ResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
  // buffer stores data starting at baseOffset
  private var buffer = Data()
  private var baseOffset: Int64 = 0 // offset in "file" corresponding to buffer[0]
  private var pendingRequests: [AVAssetResourceLoadingRequest] = []
  private let queue = DispatchQueue(label: "fmp4.resourceloader.sync")
  private let maxBufferSize = 8 * 1024 * 1024 // 8MB default, adjust if needed

  func reset() {
    queue.sync {
      buffer.removeAll(keepingCapacity: false)
      baseOffset = 0
      for req in pendingRequests {
        req.finishLoading()
      }
      pendingRequests.removeAll()
    }
  }

  func append(data chunk: Data) {
    queue.async {
      // append chunk to buffer
      self.buffer.append(chunk)
      // maybe trim old bytes if buffer too big
      self.trimBufferIfNeeded()
      // try to satisfy pending requests
      self.processPendingRequests()
    }
  }

  private func trimBufferIfNeeded() {
    if buffer.count > maxBufferSize {
      // remove oldest half
      let removeCount = buffer.count / 2
      buffer.removeFirst(removeCount)
      baseOffset += Int64(removeCount)
    }
  }

  private func processPendingRequests() {
    var finished: [AVAssetResourceLoadingRequest] = []

    for loadingRequest in pendingRequests {
      // fill content information
      if let contentInfo = loadingRequest.contentInformationRequest {
        // contentType: use public.mpeg-4 (UTI) or "video/mp4"
        contentInfo.contentType = kUTTypeMPEG4 as String // "public.mpeg-4"
        // We don't know total length (streaming). Set to a large value to signal streaming.
        contentInfo.contentLength = Int64(buffer.count) + baseOffset
        contentInfo.isByteRangeAccessSupported = true
      }

      if let dataRequest = loadingRequest.dataRequest {
        let requestedOffset = Int64(dataRequest.requestedOffset)
        let requestedLength = dataRequest.requestedLength

        // compute how many bytes are available for this request
        let availableStart = baseOffset
        let availableEnd = baseOffset + Int64(buffer.count) // exclusive

        if requestedOffset < availableEnd {
          // compute local start index in buffer
          let localStart = Int(requestedOffset - baseOffset)
          if localStart >= 0 && localStart < buffer.count {
            let availableBytes = buffer.count - localStart
            let bytesToRespond = min(availableBytes, requestedLength)
            let range = localStart ..< (localStart + bytesToRespond)
            let chunk = buffer.subdata(in: range)
            dataRequest.respond(with: chunk)
          }
        }

        // If we've satisfied requestedLength, finish this loadingRequest
        let cur = Int64(dataRequest.currentOffset)
        if cur - requestedOffset >= Int64(requestedLength) {
          loadingRequest.finishLoading()
          finished.append(loadingRequest)
        }
      }
    }

    // remove finished requests
    for r in finished {
      if let idx = pendingRequests.firstIndex(where: { $0 === r }) {
        pendingRequests.remove(at: idx)
      }
    }
  }

  // AVAssetResourceLoaderDelegate
  func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
    queue.sync {
      // fill initial content info
      if let contentInfo = loadingRequest.contentInformationRequest {
        contentInfo.contentType = kUTTypeMPEG4 as String
        contentInfo.contentLength = Int64(buffer.count) + baseOffset
        contentInfo.isByteRangeAccessSupported = true
      }
      pendingRequests.append(loadingRequest)
      // attempt to satisfy
      processPendingRequests()
    }
    return true
  }

  func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
    queue.sync {
      if let idx = pendingRequests.firstIndex(where: { $0 === loadingRequest }) {
        pendingRequests.remove(at: idx)
      }
    }
  }
}