//
//  ContentView.swift
//  EarthLord
//
//  Created by 刘文骏 on 2025/12/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
                Text("Developed by taozi")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                NavigationLink("进入测试页") {
                    TestView()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
