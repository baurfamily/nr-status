//
//  Alert.swift
//  NR Status
//
//  Created by Eric Baur on 9/24/24.
//

enum AlertSeverity : String, Codable, CaseIterable {
    case CRITICAL, NOT_ALERTING, NOT_CONFIGURED, WARNING
}