//
//  TamStarApp.swift
//  TamStar
//
//  Created by Melusine on 2025/6/24.
//
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

    init() {
        load()
    }

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
                LoginView()
                    .tabItem { Label("登录", systemImage: "person.crop.circle") }
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

// MARK: - LoginView
struct LoginView: View {
    @State private var phone = ""
    @State private var code = ""
    @State private var isSent = false
    @State private var isLogged = false

    var body: some View {
        VStack(spacing: 20) {
            Text("手机号登录").font(.largeTitle)
            TextField("请输入手机号", text: $phone)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            if !isSent {
                Button("获取验证码") { isSent = true }
                    .padding().background(Color.pink.opacity(0.2)).cornerRadius(10)
            } else {
                TextField("请输入验证码", text: $code)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                Button("登录") { isLogged = true }
                    .padding().background(Color.pink.opacity(0.2)).cornerRadius(10)
            }

            if isLogged {
                Text("登录成功 🎉").foregroundColor(.green).font(.title)
            }
            Spacer()
        }
        .padding()
    }
}

// MARK: - RecordsView
struct RecordsView: View {
    @EnvironmentObject var store: RecordsStore
    @State private var showIntervalSlider = false

    var body: some View {
        VStack {
            HStack {
                Button(action: store.addRecord) {
                    Label("记录更换", systemImage: "plus.circle.fill").font(.title2)
                }
                Spacer()
                Text("建议间隔: \(String(format: "%.1f", store.intervalHours))h")
                    .onTapGesture { showIntervalSlider.toggle() }
            }
            .padding()

            if let last = store.records.filter({ Calendar.current.isDateInToday($0.timestamp) }).last {
                Text("上次: \(dateFmt.string(from: last.timestamp)), 距今 \(Int(Date().timeIntervalSince(last.timestamp)/60)) 分钟")
                    .padding(.bottom)
            }

            List {
                ForEach(store.records.filter { Calendar.current.isDateInToday($0.timestamp) }) { rec in
                    HStack {
                        Text(dateFmt.string(from: rec.timestamp))
                        Spacer()
                        if let prev = prevRecord(rec) {
                            Text("+\(Int(rec.timestamp.timeIntervalSince(prev.timestamp)/60)) 分钟")
                        }
                        Button(action: { store.delete(rec) }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
        }
        .sheet(isPresented: $showIntervalSlider) {
            VStack {
                Text("调整建议间隔：\(String(format: "%.1f", store.intervalHours)) 小时")
                Slider(value: $store.intervalHours, in: 0.5...10, step: 0.1)
                Button("保存并关闭") { showIntervalSlider = false }
            }
            .padding()
        }
    }

    private func prevRecord(_ record: Record) -> Record? {
        let recs = store.records.filter { Calendar.current.isDateInToday($0.timestamp) }.sorted { $0.timestamp < $1.timestamp }
        guard let idx = recs.firstIndex(where: { $0.id == record.id }), idx > 0 else { return nil }
        return recs[idx - 1]
    }
}

// MARK: - CalendarView
struct CalendarView: View {
    @EnvironmentObject var store: RecordsStore
    let weekDays = ["日","一","二","三","四","五","六"]

    var body: some View {
        let weeks = makeWeeks()
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    ForEach(weekDays, id: \.self) { day in
                        Text(day).frame(maxWidth: .infinity)
                    }
                }
                ForEach(weeks.indices, id: \.self) { index in
                    HStack {
                        ForEach(weeks[index], id: \.self) { date in
                            DayCard(date: date)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func makeWeeks() -> [[Date]] {
        let calendar = Calendar.current
        let start = Date().startOfMonth
        let days = calendar.generateDays(start: start)
        return calendar.chunked(weeksOf: days)
    }
}

// MARK: - DayCard & DayDetailView
struct DayCard: View {
    var date: Date
    @EnvironmentObject var store: RecordsStore
    @State private var showDetail = false

    var body: some View {
        VStack {
            Text(date, formatter: shortFmt)
            HStack(spacing: 2) {
                ForEach(store.records.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: date) }.prefix(5), id: \.id) { _ in
                    Image(systemName: "drop.fill")
                }
            }
        }
        .padding(8)
        .background(Color.pink.opacity(0.1))
        .cornerRadius(8)
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            DayDetailView(date: date).environmentObject(store)
        }
    }
}

struct DayDetailView: View {
    var date: Date
    @EnvironmentObject var store: RecordsStore

    var recs: [Record] {
        store.records.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: date) }.sorted { $0.timestamp < $1.timestamp }
    }

    var avgInterval: Int {
        guard recs.count > 1 else { return 0 }
        let intervals = recs.dropFirst().enumerated().map { idx, r in
            Int(r.timestamp.timeIntervalSince(recs[idx].timestamp)/60)
        }
        return intervals.reduce(0, +) / intervals.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(date, formatter: longFmt).font(.headline)
            ForEach(Array(recs.enumerated()), id: \.offset) { idxRec in
                Text("\(dateFmt.string(from: idxRec.element.timestamp)) (+\(idxRec.offset > 0 ? Int(idxRec.element.timestamp.timeIntervalSince(recs[idxRec.offset-1].timestamp)/60) : 0)) 分钟")
            }
            if recs.count > 1 {
                Text("平均间隔：\(avgInterval) 分钟")
            }
            Spacer()
            Button("关闭") { dismiss() }
        }
        .padding()
    }

    @Environment(\.dismiss) private var dismiss
}

// MARK: - Formatters & Extensions
let shortFmt: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MM/dd"
    return f
}()

let longFmt: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    return f
}()

let dateFmt: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f
}()

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    var endOfDay: Date { Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1) }
    var startOfMonth: Date { Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self))! }
}

extension Calendar {
    func generateDays(start: Date) -> [Date] {
        let range = range(of: .day, in: .month, for: start)!
        return range.compactMap { day -> Date? in
            date(byAdding: .day, value: day - 1, to: start)
        }
    }
    func chunked(weeksOf days: [Date]) -> [[Date]] {
        var weeks: [[Date]] = []
        var week: [Date] = []
        for date in days {
            week.append(date)
            if Calendar.current.component(.weekday, from: date) == 7 {
                weeks.append(week)
                week = []
            }
        }
        if !week.isEmpty { weeks.append(week) }
        return weeks
    }
}

//太好啦！你现在做的非常好，现在我有好几个建议。第一 我们先把登录这个功能删除吧，他对我们现在这个阶段来说还是太早了。然后我觉得我们可以做的更漂亮一点！我们
