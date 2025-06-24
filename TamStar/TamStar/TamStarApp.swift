import SwiftUI
import Foundation

// MARK: - Model
struct Record: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
}

class RecordsStore: ObservableObject {
    @Published var records: [Record] = []
    @Published var intervalHours: Double = 3.0

    private let recordsKey = "records"
    private let intervalKey = "interval"

    init() { load() }

    func addRecord() {
        records.append(Record(id: UUID(), timestamp: Date()))
        save()
    }

    func delete(_ record: Record) {
        records.removeAll { $0.id == record.id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: recordsKey)
        }
        UserDefaults.standard.set(intervalHours, forKey: intervalKey)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: recordsKey),
           let saved = try? JSONDecoder().decode([Record].self, from: data) {
            records = saved
        }
        let iv = UserDefaults.standard.double(forKey: intervalKey)
        intervalHours = iv == 0 ? 3.0 : iv
    }
}

// MARK: - App Entry
@main
struct TamStarApp: App {
    @StateObject private var store = RecordsStore()
    var body: some Scene {
        WindowGroup {
            TabView {
                RecordsView()
                    .environmentObject(store)
                    .tabItem { Label("记录", systemImage: "plus.circle") }
                CalendarView()
                    .environmentObject(store)
                    .tabItem { Label("日历", systemImage: "calendar") }
            }
        }
    }
}

// MARK: - RecordsView
struct RecordsView: View {
    @EnvironmentObject var store: RecordsStore
    @State private var showIntervalSlider = false

    private var todayRecords: [Record] {
        store.records.filter { Calendar.current.isDateInToday($0.timestamp) }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(Date(), formatter: dateFullFmt)
                .font(.headline)
                .padding(.top)

            Text("建议间隔：\(String(format: "%.1f", store.intervalHours)) 小时")
                .onTapGesture { showIntervalSlider.toggle() }

            if let last = todayRecords.last {
                Text("上次：\(dateFmt.string(from: last.timestamp))，距今 \(Int(Date().timeIntervalSince(last.timestamp)/60)) 分钟")
                    .font(.subheadline)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(todayRecords.sorted { $0.timestamp < $1.timestamp }) { rec in
                        HStack {
                            Text(dateFmt.string(from: rec.timestamp))
                            Spacer()
                            if let prev = prevRecord(rec) {
                                Text("+\(Int(rec.timestamp.timeIntervalSince(prev.timestamp)/60)) 分钟")
                                    .font(.caption)
                            }
                            Button(action: { store.delete(rec) }) {
                                Image(systemName: "trash").foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            Button(action: store.addRecord) {
                Text("记录更换")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        .sheet(isPresented: $showIntervalSlider) {
            VStack(spacing: 16) {
                Text("调整建议间隔：\(String(format: "%.1f", store.intervalHours)) 小时")
                    .font(.headline)
                Slider(value: $store.intervalHours, in: 0.5...10, step: 0.1)
                Button("保存并关闭") { showIntervalSlider = false }
            }
            .padding()
        }
    }

    private func prevRecord(_ record: Record) -> Record? {
        let recs = todayRecords.sorted { $0.timestamp < $1.timestamp }
        guard let idx = recs.firstIndex(where: { $0.id == record.id }), idx > 0 else { return nil }
        return recs[idx - 1]
    }
}

// MARK: - CalendarView
struct CalendarView: View {
    @EnvironmentObject var store: RecordsStore
    @State private var currentDate = Date()
    @State private var selectedDate: Date?

    private var grid: [[Date?]] {
        let calendar = Calendar.current
        let start = currentDate.startOfMonth
        let range = calendar.range(of: .day, in: .month, for: start)!
        let firstWeekdayOffset = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: firstWeekdayOffset)
        days += range.map { day in
            calendar.date(byAdding: .day, value: day - 1, to: start)
        }
        while days.count % 7 != 0 { days.append(nil) }
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<$0+7]) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { changeMonth(by: -1) }) { Image(systemName: "chevron.left") }
                Spacer()
                Text(monthTitle).font(.headline)
                Spacer()
                Button(action: { changeMonth(by: 1) }) { Image(systemName: "chevron.right") }
            }
            .padding(.horizontal)

            HStack {
                ForEach(["日","一","二","三","四","五","六"], id: \.self) { day in
                    Text(day).frame(maxWidth: .infinity)
                }
            }

            ForEach(grid.indices, id: \.self) { row in
                HStack {
                    ForEach(grid[row].indices, id: \.self) { col in
                        let dateOpt = grid[row][col]
                        VStack {
                            if let date = dateOpt {
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .frame(maxWidth: .infinity)
                                    .onTapGesture { selectedDate = date }
                                HStack(spacing: 2) {
                                    ForEach(store.records.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: date) }.prefix(3), id: \.id) { _ in
                                        Image(systemName: "drop.fill").foregroundColor(.red)
                                    }
                                }
                            } else {
                                Spacer().frame(maxWidth: .infinity)
                            }
                        }
                        .padding(4)
                        .background(selectedDate != nil && dateOpt != nil && Calendar.current.isDate(selectedDate!, inSameDayAs: dateOpt!) ? Color.red.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                    }
                }
            }

            if let date = selectedDate {
                Divider().padding(.vertical)
                Text("记录详情：\(monthDetailTitle)\(Calendar.current.component(.day, from: date))日")
                    .font(.headline).padding(.horizontal)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(store.records.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: date) }.sorted { $0.timestamp < $1.timestamp }) { rec in
                        Text(dateFmt.string(from: rec.timestamp))
                    }
                }
                let recs = store.records.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: date) }.sorted { $0.timestamp < $1.timestamp }
                if recs.count > 1 {
                    Text("平均间隔：\(averageInterval(for: recs)) 分钟")
                        .font(.subheadline)
                        .padding(.top, 4)
                }
            }

            Spacer()
        }
    }

    private var monthTitle: String {
        let df = DateFormatter(); df.dateFormat = "yyyy 年 MM 月"; return df.string(from: currentDate)
    }

    private var monthDetailTitle: String {
        let df = DateFormatter(); df.dateFormat = "MM 月"; return df.string(from: currentDate)
    }

    private func changeMonth(by val: Int) {
        currentDate = Calendar.current.date(byAdding: .month, value: val, to: currentDate)!
        selectedDate = nil
    }

    private func averageInterval(for recs: [Record]) -> Int {
        guard recs.count > 1 else { return 0 }
        let ivs = recs.dropFirst().enumerated().map { idx, r in Int(r.timestamp.timeIntervalSince(recs[idx].timestamp)/60) }
        return ivs.reduce(0, +) / ivs.count
    }
}

// MARK: - Formatters & Extensions
let dateFmt: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
}()
let dateFullFmt: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
}()

extension Date {
    var startOfMonth: Date { Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self))! }
}
