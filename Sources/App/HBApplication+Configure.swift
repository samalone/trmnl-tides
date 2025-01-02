import Hummingbird
import HummingbirdFoundation
import Foundation

public enum TideType: String, Codable {
    case high = "H"
    case low = "L"
}

public enum TideStatus: String, Codable {
    case rising
    case high
    case falling
    case low
}

// The latest tide data is provided as JSON and looks like:
// { "predictions" : [
// {"t":"2025-01-02 08:48", "v":"4.415"},{"t":"2025-01-02 08:54", "v":"4.457"},{"t":"2025-01-02 09:00", "v":"4.493"},{"t":"2025-01-02 09:06", "v":"4.522"},{"t":"2025-01-02 09:12", "v":"4.545"},{"t":"2025-01-02 09:18", "v":"4.560"}
// ]}
public struct LatestTideData: Decodable {
    struct Prediction: Decodable {
        var t: Date
        var v: Double
        
        enum CodingKeys: CodingKey {
            case t
            case v
        }
        
        // Customize our JSON parsing to read the GMT Date string in CO-OPS format.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let dateString = try container.decode(String.self, forKey: .t)
            let valueString = try container.decode(String.self, forKey: .v)
            
            // Parse the date string into a Date object.
            if let date = coopsResponseFormatter.date(from: dateString) {
                t = date
            }
            else {
                throw DecodingError.dataCorruptedError(forKey: .t, in: container, debugDescription: "Date string does not match format expected by formatter: \(dateString)")
            }
            
            // Parse the value string into a Double.
            if let value = Double(valueString) {
                v = value
            }
            else {
                throw DecodingError.dataCorruptedError(forKey: .v, in: container, debugDescription: "Value string does not match format expected by formatter: \(valueString)")
            }
        }
    }
    
    var predictions: [Prediction]
}

// The high/low data is provided as JSON and looks like:
// { "predictions" : [
// {"t":"2025-01-02 02:28", "v":"-0.342", "type":"L"},{"t":"2025-01-02 09:27", "v":"4.569", "type":"H"},{"t":"2025-01-02 15:03", "v":"-0.551", "type":"L"},{"t":"2025-01-02 21:58", "v":"4.068", "type":"H"}
// ]}
public struct HighLowData: Decodable {
    struct Prediction: Decodable {
        var t: Date
        var v: Double
        var type: TideType
        
        enum CodingKeys: CodingKey {
            case t
            case v
            case type
        }
        
        init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<HighLowData.Prediction.CodingKeys> = try decoder.container(keyedBy: HighLowData.Prediction.CodingKeys.self)
            let dateString: String = try container.decode(String.self, forKey: HighLowData.Prediction.CodingKeys.t)
            let valueString: String = try container.decode(String.self, forKey: HighLowData.Prediction.CodingKeys.v)
            
            
            // Parse the date string into a Date object.
            if let date = coopsResponseFormatter.date(from: dateString) {
                t = date
            }
            else {
                throw DecodingError.dataCorruptedError(forKey: .t, in: container, debugDescription: "Date string does not match format expected by formatter: \(dateString)")
            }
            
            // Parse the value string into a Double.
            if let value = Double(valueString) {
                v = value
            }
            else {
                throw DecodingError.dataCorruptedError(forKey: .v, in: container, debugDescription: "Value string does not match format expected by formatter: \(valueString)")
            }
            
            type = try container.decode(TideType.self, forKey: HighLowData.Prediction.CodingKeys.type)
        }
    }
    
    var predictions: [Prediction]
}

// This data structure controls the JSON output.
// It is designed to make writing the TRMNL plugin as easy as possible,
// so the data is pre-formatted for display.
public struct Output: Codable, HBResponseEncodable {
    struct FutureTide: Codable {
        var time: String
        var height: String
        var type: TideStatus
    }
    
    var current: FutureTide
    var future: [FutureTide]
}

// Create a DateFormatter for NOAA CO-OPS response format, which is yyyyMMdd HH:mm
// in GMT time zone.
let coopsResponseFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
}()

// The CO-OPS API accepts dates in yyyyMMdd format and
// date/times in yyyMMdd HH:mm format. We format the space
// as + so it can be used in a URL query string.
let coopsQueryFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd+HH:mm"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
}()

public extension HBApplication {
    
    func configure() throws {
        encoder = JSONEncoder()
        
        router.get("/tides") { request async throws -> Output in
            let session = URLSession.shared
            
            let station = request.uri.queryParameters["station"] ?? "8453767"
            // If the station isn't just digits, throw an error.
            if !station.allSatisfy(\.isNumber) {
                throw HBHTTPError(.badRequest, message: "Invalid NOAA tide station ID")
            }
            
            // We perform all calculations in GMT, but convert the result to
            // the user's local time in the response.
            let tzName = request.uri.queryParameters["tz"] ?? "America/New_York"
            guard let timeZone = TimeZone(identifier: tzName) else {
                throw HBHTTPError(.badRequest, message: "Invalid time zone")
            }

            // Retrieve the latest tide information for the station.
            guard let latestURL = URL(string: "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?date=latest&station=\(station)&product=predictions&datum=MLLW&time_zone=gmt&units=english&application=Llamagraphics&format=json") else {
                throw HBHTTPError(.internalServerError)
            }
            let response = try await session.data(from: latestURL)
            let data = try JSONDecoder().decode(LatestTideData.self, from: response.0)
            
            guard let last = data.predictions.last else {
                throw HBHTTPError(.notFound)
            }
            
            let now = coopsQueryFormatter.string(from: Date())
            // We specify a 25 hour range to guarantee that we get at least 4 tides.
            guard let highLowURL = URL(string: "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?station=\(station)&product=predictions&datum=MLLW&time_zone=gmt&units=english&application=Llamagraphics&format=json&interval=hilo&begin_date=\(now)&range=25") else {
                throw HBHTTPError(.internalServerError)
            }
            let highLowResponse = try await session.data(from: highLowURL)
            let highLowData = try JSONDecoder().decode(HighLowData.self, from: highLowResponse.0)
            
            // Convert last.t to date components in the requested time zone.
            var calendar = Calendar.current
            calendar.timeZone = timeZone
            let localDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: last.t)
            
            guard let nextTide = highLowData.predictions.first else {
                throw HBHTTPError(.notFound)
            }
            
            // Classify the current tide status. It is rising if the next tide is high,
            // or falling if the next tide is low. If we are within 30 minutes of either
            // side of the next tide, just call it high or low.
            let status: TideStatus
            if abs(last.t.timeIntervalSince(nextTide.t)) < 30 * 60 {
                status = nextTide.type == .high ? .high : .low
            }
            else {
                status = nextTide.type == .high ? .rising : .falling
            }
            
            // Convert just the time portion of last.t to AM/PM format.
            let latestTideTime: String
            if let hour = localDateComponents.hour,
               let minute = localDateComponents.minute {
                
                if hour > 12 {
                    latestTideTime = "\(hour - 12):\(String(format: "%02d", minute)) PM"
                }
                else {
                    latestTideTime = "\(hour):\(String(format: "%02d", minute)) AM"
                }
            }
            else {
                throw HBHTTPError(.internalServerError)
            }
            
            // Parse last.v as a double and format it to one decimal place.
            let latestTideHeight = String(format: "%.1f", last.v)
            
            return Output(current: Output.FutureTide(time: latestTideTime,
                                                      height: latestTideHeight,
                                                      type: status),
                          future: try highLowData.predictions.map { prediction in
                            let localComponents = calendar.dateComponents([.hour, .minute], from: prediction.t)
                            let time: String
                            if let hour = localComponents.hour,
                               let minute = localComponents.minute {
                                
                                if hour > 12 {
                                    time = "\(hour - 12):\(String(format: "%02d", minute)) PM"
                                }
                                else {
                                    time = "\(hour):\(String(format: "%02d", minute)) AM"
                                }
                            }
                            else {
                                throw HBHTTPError(.internalServerError)
                            }
                
                            let status = prediction.type == .high ? TideStatus.high : TideStatus.low
                            
                            let height = String(format: "%.1f", prediction.v)
                            return Output.FutureTide(time: time, height: height, type: status)
                          })
        }
    }
}
