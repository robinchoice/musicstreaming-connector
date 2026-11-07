import SwiftUI
import UIKit
import CoreText

// Colours of the app, see lib/core/brand.dart
private enum Brand {
    static let background = Color(hex: 0x0E0D12)
    static let raised = Color(hex: 0x201F25)
    static let text = Color(hex: 0xF2F0EA)
    static let muted = Color(hex: 0x9A98A3)
    static let ink = Color(hex: 0x17171A)
    static let hairline = Color.white.opacity(0.07)
    static let hairlineStrong = Color.white.opacity(0.14)
    static func displayFont(size: CGFloat) -> Font {
        let descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontNameAttribute as String: "BricolageGrotesque-96ptExtraBold",
            kCTFontVariationAttribute as String: [0x77647468: 80.0, 0x77676874: 780.0]
        ] as CFDictionary)
        return Font(CTFontCreateWithFontDescriptor(descriptor, size, nil))
    }
    // The band 3.85 to 4.55 on glow, only for the main action and picked items
    static let accent = Color(hex: 0x64CC9E)
    static let gradient = LinearGradient(
        colors: [Color(hex: 0x80CD84), accent, Color(hex: 0x57C6BB)],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    init(hue: Double, saturation: Double, lightness: Double) {
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let x = chroma * (1 - abs((hue / 60).truncatingRemainder(dividingBy: 2) - 1))
        let (r, g, b): (Double, Double, Double) = switch Int(hue / 60) % 6 {
        case 0: (chroma, x, 0)
        case 1: (x, chroma, 0)
        case 2: (0, chroma, x)
        case 3: (0, x, chroma)
        case 4: (x, 0, chroma)
        default: (chroma, 0, x)
        }
        let m = lightness - chroma / 2
        self.init(red: r + m, green: g + m, blue: b + m)
    }
}

// Simple Icons (CC0) like assets/logos, converted to absolute M, L, H, V, C and Z
// with svgpath: svgpath(d).abs().unarc().unshort().round(3)
struct ServiceLogo: View {
    let platform: String
    var kind = "song"
    var size: CGFloat = 24

    private static let colors: [String: UInt32] = ["applePodcasts": 0x9933CC, "appleMusic": 0xFA243C, "youtubeMusic": 0xFF0033, "spotify": 0x1ED760, "deezer": 0xA238FF, "tidal": 0xFFFFFF, "amazonMusic": 0x25D1DA]
    private static let paths: [String: String] = [
        "applePodcasts": "M5.34 0C3.923-0.003 2.563 0.558 1.561 1.561 0.558 2.563-0.003 3.923 0 5.34V18.66C-0.003 20.077 0.558 21.437 1.561 22.439 2.563 23.442 3.923 24.003 5.34 24H18.66C20.077 24.003 21.437 23.442 22.439 22.439 23.442 21.437 24.003 20.077 24 18.66V5.34C24.003 3.923 23.442 2.563 22.439 1.561 21.437 0.558 20.077-0.003 18.66 0ZM11.865 2.568C14.201 2.568 16.313 3.47 17.921 5.155 19.145 6.427 19.833 7.774 20.185 9.547 20.305 10.137 20.305 11.747 20.192 12.411 19.818 14.522 18.661 16.413 16.952 17.707 16.344 18.167 14.856 18.968 14.616 18.968 14.528 18.968 14.52 18.877 14.56 18.508 14.632 17.916 14.704 17.793 15.04 17.652 15.576 17.428 16.488 16.778 17.048 16.217 18.024 15.241 18.718 14.019 19.056 12.681 19.264 11.857 19.24 10.025 19.008 9.177 18.28 6.481 16.08 4.385 13.384 3.825 12.6 3.665 11.176 3.665 10.384 3.825 7.656 4.385 5.4 6.585 4.712 9.353 4.528 10.105 4.528 11.937 4.712 12.689 5.168 14.521 6.352 16.201 7.904 17.201 8.208 17.401 8.576 17.609 8.728 17.673 9.064 17.817 9.136 17.937 9.2 18.529 9.24 18.889 9.23 18.993 9.144 18.993 9.088 18.993 8.68 18.817 8.248 18.609L8.208 18.579C5.736 17.363 4.152 15.305 3.576 12.567 3.432 11.861 3.408 10.175 3.546 9.527 3.906 7.787 4.594 6.427 5.738 5.223 7.386 3.486 9.506 2.567 11.866 2.567ZM11.999 5.378C12.408 5.382 12.802 5.418 13.105 5.484 15.889 6.104 17.865 8.892 17.481 11.658 17.329 12.772 16.945 13.688 16.265 14.538 15.929 14.968 15.113 15.688 14.969 15.688 14.946 15.688 14.921 15.416 14.921 15.085V14.48L15.337 13.984C16.905 12.106 16.793 9.482 15.081 7.76 14.417 7.09 13.649 6.696 12.657 6.514 12.017 6.396 11.881 6.396 11.209 6.506 10.189 6.673 9.399 7.068 8.697 7.762 6.977 9.466 6.865 12.104 8.433 13.984L8.846 14.48V15.088C8.846 15.424 8.819 15.696 8.786 15.696 8.756 15.696 8.522 15.536 8.274 15.336L8.24 15.325C7.408 14.661 6.672 13.483 6.368 12.328 6.184 11.63 6.184 10.304 6.376 9.608 6.88 7.73 8.264 6.273 10.184 5.589 10.594 5.444 11.317 5.369 11.998 5.378ZM11.869 8.368C12.179 8.368 12.489 8.428 12.713 8.546 13.201 8.799 13.601 9.291 13.753 9.805 14.217 11.383 12.545 12.765 11.033 12.059H11.018C10.306 11.728 9.922 11.103 9.914 10.289 9.914 9.556 10.322 8.918 11.026 8.544 11.25 8.427 11.56 8.368 11.87 8.368ZM11.858 13.096C12.846 13.092 13.564 13.445 13.828 14.066 14.026 14.53 13.952 15.998 13.61 18.368 13.378 20.024 13.25 20.442 12.93 20.724 12.49 21.114 11.866 21.222 11.274 21.012H11.271C10.555 20.755 10.401 20.407 10.107 18.368 9.766 15.998 9.691 14.53 9.889 14.066 10.151 13.45 10.863 13.1 11.859 13.096Z",
        "appleMusic": "M23.994 6.124C24.002 5.387 23.921 4.652 23.754 3.934 23.437 2.624 22.692 1.624 21.574 0.891 21.004 0.525 20.365 0.278 19.697 0.165 19.18 0.076 18.657 0.026 18.133 0.015 18.093 0.012 18.05 0.005 18.009 0.002H5.986C5.834 0.012 5.683 0.019 5.531 0.028 4.784 0.071 4.041 0.151 3.338 0.428 2.002 0.958 1.038 1.88 0.473 3.208 0.281 3.656 0.181 4.133 0.11 4.616 0.054 5.008 0.022 5.401 0.01 5.796 0.01 5.828 0.003 5.858 0 5.889V18.112C0.01 18.252 0.017 18.395 0.027 18.536 0.077 19.351 0.181 20.16 0.524 20.909 1.174 22.329 2.262 23.262 3.758 23.71 4.178 23.837 4.614 23.897 5.051 23.938 5.606 23.991 6.161 23.998 6.718 23.998H17.748C18.273 23.998 18.797 23.964 19.318 23.898 20.14 23.792 20.914 23.548 21.613 23.088 22.442 22.552 23.096 21.785 23.493 20.881 23.679 20.461 23.786 20.011 23.863 19.557 23.976 18.882 24.001 18.199 24 17.517 23.998 13.717 24 9.922 23.997 6.124ZM17.571 10.114V15.826C17.571 16.243 17.513 16.653 17.327 17.032 17.037 17.622 16.567 17.994 15.939 18.172 15.589 18.272 15.233 18.329 14.869 18.345 13.919 18.39 13.096 17.745 12.926 16.809 12.779 15.978 13.204 15.152 13.964 14.787 14.287 14.627 14.634 14.537 14.982 14.463 15.36 14.381 15.74 14.31 16.116 14.223 16.39 14.16 16.573 13.993 16.626 13.707 16.64 13.644 16.646 13.579 16.646 13.514 16.646 11.699 16.646 9.884 16.644 8.071 16.643 8.008 16.635 7.946 16.618 7.886 16.578 7.736 16.468 7.643 16.314 7.652 16.154 7.662 15.996 7.687 15.839 7.718 15.079 7.868 14.319 8.021 13.559 8.174L11.234 8.644 9.86 8.922C9.844 8.925 9.828 8.932 9.812 8.935 9.535 9.012 9.435 9.138 9.422 9.425 9.42 9.467 9.422 9.511 9.422 9.555 9.42 12.157 9.422 14.759 9.419 17.36 9.419 17.78 9.372 18.196 9.204 18.587 8.926 19.227 8.434 19.627 7.77 19.82 7.42 19.92 7.06 19.98 6.695 19.992 5.735 20.028 4.94 19.392 4.775 18.448 4.635 17.636 5.005 16.763 5.929 16.373 6.286 16.223 6.659 16.141 7.037 16.063 7.324 16.003 7.612 15.947 7.897 15.886 8.28 15.803 8.48 15.563 8.497 15.172V15.022C8.497 12.062 8.497 9.1 8.499 6.14 8.499 6.017 8.512 5.89 8.541 5.77 8.611 5.485 8.814 5.322 9.087 5.252 9.342 5.186 9.602 5.14 9.861 5.087 10.594 4.937 11.327 4.791 12.061 4.643L14.331 4.183C15.001 4.049 15.671 3.913 16.341 3.78 16.561 3.737 16.783 3.692 17.004 3.674 17.314 3.649 17.527 3.844 17.558 4.156 17.566 4.229 17.57 4.304 17.57 4.379 17.572 6.289 17.572 8.201 17.57 10.111Z",
        "youtubeMusic": "M12 0C5.376 0 0 5.376 0 12 0 18.624 5.376 24 12 24 18.624 24 24 18.624 24 12 24 5.376 18.624 0 12 0ZM12 19.104C8.076 19.104 4.896 15.924 4.896 12 4.896 8.076 8.076 4.896 12 4.896 15.924 4.896 19.104 8.076 19.104 12 19.104 15.924 15.924 19.104 12 19.104ZM12 5.772C8.568 5.772 5.772 8.568 5.772 12 5.772 15.432 8.568 18.228 12 18.228 15.432 18.228 18.228 15.432 18.228 12 18.228 8.568 15.432 5.772 12 5.772ZM9.684 15.54V8.46L15.816 12 9.684 15.54Z",
        "spotify": "M12 0C5.4 0 0 5.4 0 12 0 18.6 5.4 24 12 24 18.6 24 24 18.6 24 12 24 5.4 18.66 0 12 0ZM17.521 17.34C17.281 17.699 16.861 17.82 16.5 17.58 13.68 15.84 10.14 15.479 5.939 16.439 5.521 16.561 5.16 16.26 5.04 15.9 4.92 15.479 5.22 15.12 5.58 15 10.14 13.979 14.1 14.4 17.22 16.32 17.64 16.5 17.699 16.979 17.521 17.34ZM18.961 14.04C18.66 14.46 18.12 14.64 17.699 14.34 14.46 12.36 9.54 11.76 5.76 12.96 5.281 13.08 4.74 12.84 4.62 12.36 4.5 11.88 4.74 11.339 5.22 11.219 9.6 9.9 15 10.561 18.72 12.84 19.081 13.021 19.26 13.62 18.961 14.04ZM19.081 10.68C15.24 8.4 8.82 8.16 5.16 9.301 4.56 9.48 3.96 9.12 3.78 8.58 3.6 7.979 3.96 7.38 4.5 7.199 8.76 5.939 15.78 6.179 20.221 8.82 20.76 9.12 20.94 9.84 20.64 10.38 20.341 10.801 19.62 10.979 19.081 10.68Z",
        "deezer": "M0.693 10.024C1.074 10.024 1.386 8.768 1.386 7.217 1.386 5.667 1.074 4.41 0.693 4.41 0.312 4.41 0 5.666 0 7.217 0 8.768 0.312 10.025 0.693 10.025ZM21.038 1.56C20.674 1.56 20.354 2.365 20.128 3.656 19.765 1.446 19.184 0 18.526 0 17.746 0 17.062 2.036 16.742 5 16.43 2.842 15.954 1.464 15.417 1.464 14.672 1.464 14.031 4.168 13.797 7.936 13.355 6.004 12.714 4.791 12.004 4.791 11.294 4.791 10.654 6.004 10.211 7.936 9.969 4.176 9.337 1.473 8.583 1.473 8.046 1.473 7.57 2.851 7.258 5.008 6.938 2.036 6.262 0 5.474 0 4.816 0 4.227 1.447 3.872 3.665 3.655 2.374 3.326 1.56 2.962 1.56 2.287 1.56 1.741 4.367 1.741 7.832 1.741 11.298 2.287 14.105 2.962 14.105 3.239 14.105 3.499 13.629 3.698 12.832 4.018 15.76 4.694 17.77 5.474 17.77 6.08 17.77 6.617 16.566 6.981 14.66 7.232 18.282 7.856 20.855 8.583 20.855 9.043 20.855 9.458 19.832 9.77 18.178 10.142 21.6 11 24 12.004 24 13.009 24 13.867 21.6 14.239 18.178 14.551 19.832 14.966 20.855 15.425 20.855 16.153 20.855 16.777 18.282 17.028 14.66 17.392 16.566 17.928 17.77 18.535 17.77 19.315 17.77 19.99 15.76 20.31 12.832 20.518 13.629 20.77 14.105 21.047 14.105 21.722 14.105 22.267 11.298 22.267 7.832 22.259 4.375 21.714 1.56 21.037 1.56ZM23.307 10.024C23.688 10.024 24 8.768 24 7.217 24 5.667 23.688 4.41 23.307 4.41 22.926 4.41 22.614 5.666 22.614 7.217 22.614 8.768 22.926 10.025 23.307 10.025Z",
        "tidal": "M12.012 3.992L8.008 7.996 4.004 3.992 0 7.996 4.004 12 8.008 7.996 12.012 12 8.008 16.004 12.012 20.008 16.016 16.004 12.012 12 16.016 7.996 12.012 3.992ZM16.042 7.996L20.021 4.017 24 7.996 20.021 11.975Z",
        "amazonMusic": "M14.845 9.408C13.455 10.428 11.44 10.971 9.703 10.971 7.388 10.983 5.15 10.133 3.426 8.588 3.295 8.471 3.412 8.311 3.568 8.403 5.483 9.492 7.649 10.063 9.853 10.061 11.391 10.061 13.088 9.743 14.644 9.084 14.88 8.986 15.077 9.238 14.847 9.408H14.845ZM15.424 8.752C15.245 8.526 14.248 8.643 13.801 8.697 13.664 8.713 13.643 8.594 13.766 8.51 14.562 7.954 15.865 8.114 16.017 8.301 16.171 8.487 15.976 9.788 15.231 10.409 15.116 10.506 15.007 10.454 15.059 10.327 15.227 9.911 15.602 8.978 15.424 8.752ZM13.832 4.582V4.042C13.832 3.96 13.894 3.905 13.97 3.905H16.404C16.482 3.905 16.544 3.96 16.544 4.04V4.504C16.544 4.582 16.478 4.684 16.359 4.844L15.1 6.635C15.567 6.625 16.064 6.694 16.488 6.932 16.585 6.986 16.611 7.066 16.618 7.144V7.718C16.618 7.8 16.529 7.89 16.439 7.841 15.631 7.429 14.673 7.431 13.867 7.847 13.781 7.892 13.693 7.802 13.693 7.722V7.174C13.693 7.086 13.695 6.936 13.783 6.803L15.245 4.715H13.974C13.896 4.715 13.832 4.662 13.83 4.58L13.832 4.582ZM18.64 3.835C19.74 3.835 20.334 4.775 20.334 5.968 20.334 7.121 19.678 8.036 18.64 8.036 17.561 8.036 16.975 7.097 16.975 5.927 16.975 4.75 17.569 3.835 18.64 3.835ZM18.646 4.606C18.101 4.606 18.066 5.345 18.066 5.808 18.066 6.27 18.06 7.257 18.64 7.257 19.215 7.257 19.241 6.461 19.241 5.975 19.241 5.657 19.227 5.275 19.13 4.974 19.048 4.711 18.882 4.606 18.646 4.606ZM12.638 7.948C12.589 7.989 12.499 7.993 12.464 7.964 12.21 7.769 12.039 7.472 12.039 7.472 11.633 7.884 11.344 8.009 10.817 8.009 10.195 8.009 9.709 7.626 9.709 6.861 9.692 6.333 10.008 5.851 10.499 5.657 10.901 5.48 11.463 5.449 11.892 5.4 11.892 5.4 11.927 4.939 11.801 4.771 11.699 4.646 11.546 4.576 11.385 4.58 11.112 4.58 10.846 4.727 10.792 5.013 10.778 5.095 10.718 5.164 10.653 5.156L9.945 5.08C9.909 5.076 9.877 5.056 9.856 5.027 9.835 4.998 9.827 4.962 9.834 4.926 9.998 4.061 10.784 3.798 11.49 3.798 11.851 3.798 12.32 3.895 12.605 4.165 12.964 4.5 12.932 4.945 12.932 5.433V6.582C12.932 6.926 13.075 7.078 13.211 7.263 13.258 7.33 13.268 7.41 13.209 7.46 13.057 7.585 12.638 7.948 12.638 7.948ZM11.892 6.151V5.991C11.356 5.991 10.79 6.106 10.79 6.734 10.79 7.052 10.956 7.267 11.241 7.267 11.447 7.267 11.635 7.14 11.754 6.932 11.898 6.676 11.892 6.438 11.892 6.151ZM2.928 7.948C2.881 7.989 2.79 7.993 2.756 7.964 2.501 7.769 2.331 7.472 2.331 7.472 1.923 7.884 1.636 8.009 1.108 8.009 0.485 8.009 0.001 7.626 0.001 6.861-0.017 6.333 0.299 5.851 0.79 5.657 1.192 5.48 1.754 5.45 2.183 5.4 2.183 5.4 2.218 4.939 2.093 4.771 1.991 4.646 1.837 4.576 1.677 4.58 1.402 4.58 1.137 4.728 1.084 5.013 1.069 5.095 1.008 5.164 0.944 5.156L0.234 5.08C0.199 5.075 0.168 5.056 0.147 5.027 0.126 4.998 0.119 4.961 0.126 4.926 0.288 4.061 1.075 3.798 1.781 3.798 2.142 3.798 2.612 3.895 2.897 4.165 3.256 4.5 3.221 4.945 3.221 5.433V6.582C3.221 6.926 3.365 7.078 3.5 7.263 3.547 7.33 3.557 7.41 3.498 7.46 3.346 7.585 2.928 7.948 2.928 7.948ZM2.183 6.151V5.991C1.648 5.991 1.082 6.106 1.082 6.734 1.082 7.052 1.246 7.267 1.533 7.267 1.738 7.267 1.927 7.14 2.046 6.933 2.189 6.676 2.183 6.438 2.183 6.151ZM5.096 5.817V7.819C5.096 7.855 5.081 7.891 5.055 7.916 5.029 7.942 4.993 7.957 4.956 7.956H4.218C4.181 7.957 4.146 7.942 4.119 7.917 4.093 7.891 4.078 7.856 4.079 7.819V4.053C4.079 4.016 4.093 3.981 4.12 3.955 4.146 3.929 4.181 3.915 4.218 3.915H4.909C4.946 3.915 4.981 3.93 5.006 3.955 5.032 3.981 5.047 4.016 5.047 4.053V4.535H5.061C5.242 4.059 5.58 3.835 6.035 3.835 6.499 3.835 6.788 4.059 6.997 4.535 7.15 4.105 7.563 3.822 8.019 3.835 8.331 3.835 8.669 3.962 8.876 4.25 9.112 4.568 9.063 5.029 9.063 5.435V7.821C9.063 7.897 8.999 7.956 8.919 7.956H8.181C8.107 7.954 8.049 7.894 8.048 7.821V5.817C8.048 5.657 8.062 5.259 8.027 5.109 7.972 4.853 7.806 4.781 7.59 4.781 7.394 4.788 7.221 4.91 7.149 5.093 7.073 5.283 7.079 5.601 7.079 5.817V7.821C7.079 7.897 7.016 7.956 6.936 7.956H6.197C6.124 7.954 6.065 7.894 6.064 7.821V5.817C6.064 5.394 6.132 4.775 5.607 4.775 5.073 4.775 5.094 5.378 5.094 5.817H5.096ZM21.904 7.819C21.904 7.895 21.842 7.956 21.766 7.956H21.026C20.95 7.956 20.888 7.895 20.888 7.819V4.053C20.888 4.016 20.903 3.981 20.929 3.955 20.954 3.93 20.989 3.915 21.026 3.915H21.709C21.791 3.915 21.848 3.979 21.848 4.022V4.598H21.863C22.068 4.081 22.359 3.835 22.872 3.835 23.204 3.835 23.528 3.954 23.735 4.28 23.928 4.584 23.928 5.093 23.928 5.458V7.837C23.918 7.907 23.857 7.958 23.787 7.956H23.044C22.978 7.953 22.923 7.903 22.913 7.837V5.552C22.913 4.789 22.62 4.766 22.449 4.766 22.252 4.766 22.092 4.92 22.025 5.062 21.932 5.291 21.89 5.537 21.902 5.784L21.904 7.819ZM0.191 20.058C0.064 20.058 0.001 19.997 0.001 19.867V15.418C0.001 15.291 0.064 15.228 0.191 15.228H0.616C0.678 15.228 0.729 15.242 0.764 15.267 0.799 15.291 0.823 15.34 0.836 15.41L0.893 15.714C1.506 15.295 2.103 15.086 2.684 15.086 3.279 15.086 3.681 15.312 3.892 15.763 4.524 15.312 5.155 15.086 5.787 15.086 6.228 15.086 6.567 15.209 6.803 15.455 7.038 15.706 7.157 16.058 7.157 16.514V19.867C7.157 19.995 7.092 20.058 6.965 20.058H6.401C6.273 20.058 6.208 19.997 6.208 19.867V16.782C6.208 16.464 6.146 16.229 6.027 16.077 5.904 15.923 5.713 15.847 5.453 15.847 4.985 15.847 4.518 15.991 4.044 16.278 4.05 16.325 4.054 16.372 4.054 16.419V19.867C4.054 19.995 3.99 20.058 3.863 20.058H3.297C3.17 20.058 3.106 19.997 3.106 19.867V16.782C3.106 16.464 3.045 16.229 2.924 16.077 2.801 15.923 2.61 15.847 2.349 15.847 1.863 15.847 1.398 15.987 0.95 16.268V19.867C0.95 19.995 0.889 20.058 0.76 20.058H0.191ZM9.922 20.202C9.469 20.202 9.122 20.075 8.878 19.82 8.636 19.566 8.515 19.207 8.515 18.743V15.422C8.515 15.293 8.577 15.23 8.706 15.23H9.27C9.399 15.23 9.463 15.293 9.463 15.42V18.442C9.463 18.784 9.529 19.037 9.664 19.199 9.797 19.361 10.013 19.441 10.306 19.441 10.765 19.441 11.229 19.289 11.695 18.983V15.418C11.695 15.291 11.756 15.228 11.885 15.228H12.449C12.579 15.228 12.642 15.291 12.642 15.418V19.87C12.642 19.995 12.579 20.058 12.45 20.058H12.039C11.976 20.058 11.924 20.046 11.89 20.021 11.855 19.995 11.832 19.948 11.818 19.878L11.752 19.545C11.157 19.982 10.548 20.202 9.922 20.202ZM15.362 20.202C14.825 20.202 14.343 20.114 13.916 19.935 13.855 19.914 13.801 19.878 13.758 19.83 13.729 19.791 13.715 19.732 13.715 19.65V19.381C13.715 19.267 13.752 19.209 13.83 19.209 13.875 19.209 13.953 19.229 14.068 19.267 14.491 19.4 14.93 19.466 15.381 19.466 15.695 19.466 15.933 19.404 16.095 19.285 16.259 19.164 16.339 18.99 16.339 18.762 16.345 18.622 16.291 18.486 16.191 18.389 16.03 18.26 15.847 18.163 15.649 18.104L14.835 17.8C14.125 17.539 13.773 17.094 13.773 16.467 13.773 16.052 13.933 15.718 14.257 15.466 14.579 15.211 15.001 15.084 15.524 15.084 15.94 15.084 16.352 15.158 16.741 15.304 16.817 15.328 16.872 15.361 16.905 15.402 16.936 15.443 16.952 15.505 16.952 15.587V15.845C16.952 15.96 16.911 16.017 16.829 16.017 16.753 16.011 16.679 15.996 16.607 15.97 16.272 15.868 15.923 15.816 15.572 15.816 14.96 15.816 14.653 16.024 14.653 16.436 14.653 16.6 14.704 16.731 14.807 16.826 14.909 16.922 15.11 17.027 15.41 17.141L16.156 17.429C16.534 17.572 16.804 17.747 16.971 17.948 17.137 18.146 17.219 18.405 17.219 18.723 17.219 19.174 17.051 19.533 16.712 19.8 16.374 20.066 15.924 20.2 15.362 20.2V20.202ZM18.427 20.058C18.3 20.058 18.234 19.997 18.234 19.867V15.418C18.234 15.291 18.3 15.228 18.427 15.228H18.991C19.118 15.228 19.184 15.291 19.184 15.418V19.87C19.184 19.995 19.118 20.058 18.991 20.058H18.427ZM18.714 14.37C18.529 14.37 18.384 14.319 18.277 14.214 18.169 14.104 18.112 13.954 18.119 13.8 18.119 13.628 18.172 13.49 18.277 13.386 18.395 13.275 18.553 13.218 18.714 13.228 18.899 13.228 19.042 13.281 19.149 13.386 19.255 13.488 19.307 13.628 19.307 13.8 19.307 13.97 19.255 14.108 19.149 14.214 19.044 14.317 18.899 14.37 18.714 14.37ZM22.716 20.163C21.963 20.163 21.387 19.95 20.989 19.521 20.589 19.09 20.39 18.471 20.39 17.658 20.39 16.852 20.595 16.227 21.007 15.786 21.417 15.345 22.002 15.123 22.755 15.123 23.099 15.123 23.438 15.185 23.77 15.306 23.84 15.33 23.889 15.361 23.918 15.4 23.947 15.439 23.961 15.503 23.961 15.591V15.847C23.961 15.974 23.92 16.038 23.838 16.038 23.805 16.038 23.756 16.03 23.684 16.009 23.426 15.934 23.158 15.896 22.888 15.896 22.353 15.896 21.965 16.03 21.729 16.3 21.493 16.571 21.376 17 21.376 17.593V17.716C21.376 18.292 21.495 18.717 21.735 18.988 21.975 19.256 22.353 19.392 22.87 19.392 23.136 19.392 23.424 19.349 23.731 19.258 23.803 19.238 23.85 19.23 23.875 19.23 23.957 19.23 24 19.293 24 19.42V19.679C24 19.761 23.988 19.822 23.961 19.859 23.936 19.896 23.885 19.931 23.809 19.962 23.495 20.097 23.132 20.163 22.716 20.163Z",
    ]

    private static let parsedPaths = paths.mapValues(LogoShape.parse)

    var body: some View {
        let mark = platform == "appleMusic" && ShareModel.isPodcast(kind) ? "applePodcasts" : platform
        return LogoShape(logo: Self.parsedPaths[mark] ?? Path())
            .fill(Color(hex: Self.colors[mark] ?? 0x9A98A3))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct LogoShape: Shape {
    let logo: Path

    func path(in rect: CGRect) -> Path {
        logo.applying(CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: rect.width / 24, y: rect.height / 24))
    }

    static func parse(_ d: String) -> Path {
        // Commands and numbers; a minus or a second dot starts a new number
        var tokens: [String] = []
        var digits = ""
        func flush() {
            if !digits.isEmpty { tokens.append(digits) }
            digits = ""
        }
        for character in d {
            if character.isLetter {
                flush()
                tokens.append(String(character))
            } else if character == " " || character == "," {
                flush()
            } else {
                if character == "-" || (character == "." && digits.contains(".")) { flush() }
                digits.append(character)
            }
        }
        flush()
        var path = Path()
        var command = "M"
        var index = 0
        var current = CGPoint.zero
        func number() -> CGFloat {
            defer { index += 1 }
            return CGFloat(Double(tokens[index]) ?? 0)
        }
        func point() -> CGPoint { CGPoint(x: number(), y: number()) }
        while index < tokens.count {
            if let letter = tokens[index].first, letter.isLetter {
                command = tokens[index]
                index += 1
                if command == "Z" { path.closeSubpath(); continue }
            }
            switch command {
            case "M":
                current = point()
                path.move(to: current)
                command = "L"
            case "L": current = point(); path.addLine(to: current)
            case "H": current.x = number(); path.addLine(to: current)
            case "V": current.y = number(); path.addLine(to: current)
            case "C":
                let control1 = point(), control2 = point()
                current = point()
                path.addCurve(to: current, control1: control1, control2: control2)
            default: index += 1
            }
        }
        return path
    }
}

// Initial on a steady colour per name with the friend's service as a badge, the same as in the app
private struct FriendAvatar: View {
    let friend: Friend
    var size: CGFloat = 28

    var body: some View {
        let hue = Double(friend.name.utf16.reduce(7) { ($0 * 31 + Int($1)) % 360 })
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Color(hue: hue, saturation: 0.35, lightness: 0.30))
                .frame(width: size, height: size)
                .overlay(
                    Text(String(friend.name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundStyle(Color(hue: hue, saturation: 0.6, lightness: 0.88))
                )
                .padding([.trailing, .bottom], 3)
            ServiceLogo(platform: friend.platform, size: (size * 0.38).rounded())
                .padding(2)
                .background(Circle().fill(Brand.background))
        }
        .accessibilityHidden(true)
    }
}

// A rounded chip, its border turns into the gradient when picked
private struct PickChip<Leading: View>: View {
    let label: String
    let selected: Bool
    let action: () -> Void
    var leadingPadding: CGFloat = 5
    @ViewBuilder var leading: Leading

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                leading
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.text)
                    .lineLimit(1)
            }
            .padding(.leading, leadingPadding)
            .padding(.trailing, 14)
            .frame(minHeight: 38)
            .background(Capsule().fill(selected ? Brand.raised : Color.white.opacity(0.03)))
            .overlay(
                Capsule().strokeBorder(selected ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Brand.hairlineStrong), lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ShareView: View {
    @ObservedObject var model: ShareModel
    // Sent or copied for the picked friends
    let sent: () -> Void
    let finish: () -> Void
    @State private var shareItem: SharedItem?
    @State private var copied = false
    @State private var showingGuide = false
    @ScaledMetric(relativeTo: .title2) private var titleSize: CGFloat = 22
    @ScaledMetric(relativeTo: .headline) private var brandSize: CGFloat = 17
    @ScaledMetric(relativeTo: .subheadline) private var sectionSize: CGFloat = 15

    var body: some View {
        NavigationStack {
            ZStack {
                Brand.background.ignoresSafeArea()
                if let song = model.song {
                    AsyncImage(url: song.source.artworkUrl.flatMap(URL.init(string:))) { phase in
                        ZStack {
                            backdrop(phase.image)
                            result(song, image: phase.image)
                        }
                    }
                } else if model.isLoading {
                    VStack(spacing: 16) {
                        if let source = model.input.flatMap({ ShareModel.sourceOf($0) }) {
                            ServiceLogo(platform: source, size: 36)
                        }
                        ProgressView()
                        Text(model.t.searching)
                            .foregroundStyle(Brand.muted)
                    }
                    .accessibilityElement(children: .combine)
                } else if let error = model.error {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundStyle(Brand.muted)
                        Text(error)
                            .multilineTextAlignment(.center)
                        if model.canRetry {
                            Button(model.t.retry, action: model.retry)
                                .buttonStyle(MainButtonStyle())
                        }
                    }
                    .padding(24)
                }
            }
            .foregroundStyle(Brand.text)
            .navigationTitle("Songgate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Brand.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Songgate")
                        .font(Brand.displayFont(size: brandSize))
                        .tracking(-0.035 * brandSize)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingGuide = true } label: {
                        Image(systemName: "star")
                    }
                    .accessibilityLabel(model.t.handy)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.t.close, action: finish)
                }
            }
        }
        .tint(Brand.accent)
        .preferredColorScheme(.dark)
        .onChange(of: model.song?.sharePath) { _ in
            guard model.shareWhenFound, let message = model.message else { return }
            model.shareWhenFound = false
            shareItem = SharedItem(items: [message])
        }
        .sheet(isPresented: $showingGuide) {
            NavigationStack {
                Form {
                    Text(model.t.guide)
                }
                .navigationTitle(model.t.handy)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(model.t.handy)
                            .font(Brand.displayFont(size: brandSize))
                            .tracking(-0.035 * brandSize)
                            .accessibilityAddTraits(.isHeader)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(model.t.done) { showingGuide = false }
                    }
                }
            }
            .tint(Brand.accent)
            .preferredColorScheme(.dark)
        }
        .popover(item: $shareItem) { item in
            ActivitySheet(items: item.items) { completed in
                shareItem = nil
                if completed {
                    sent()
                    finish()
                }
            }
        }
    }

    // The cover, blurred far behind the result, tints the page
    private func backdrop(_ image: Image?) -> some View {
        Color.clear
            .frame(height: 360)
            .overlay {
                if let image {
                    image.resizable().scaledToFill()
                }
            }
            .clipped()
            .blur(radius: 60)
            .opacity(0.26)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func result(_ song: Song, image: Image?) -> some View {
        let message = model.message
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if let image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "music.note")
                            .font(.largeTitle)
                            .foregroundStyle(Brand.muted)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Brand.raised)
                    }
                }
                .frame(width: 148, height: 148)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                .accessibilityHidden(true)
                Text(model.t.kindFrom(song.source.kind, ShareModel.serviceName(song.source.platform, song.source.kind)))
                    .font(.subheadline)
                    .foregroundStyle(Brand.muted)
                    .padding(.top, 16)
                Text(song.source.title)
                    .font(Brand.displayFont(size: titleSize))
                    .tracking(-0.035 * titleSize)
                    .padding(.top, 4)
                if !song.source.artist.isEmpty {
                    Text(song.source.artist)
                        .foregroundStyle(Brand.text.opacity(0.8))
                        .padding(.top, 2)
                }
                friendsSection
                    .padding(.top, 20)
                tiles(song)
                    .padding(.top, 16)
                if let message {
                    messageBox(message)
                        .padding(.top, 14)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            if let message {
                actions(message)
            }
        }
    }

    // "An wen?": everyone, a group or friends. Picking people picks their services.
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.t.toWhom)
                .font(Brand.displayFont(size: sectionSize))
                .tracking(-0.035 * sectionSize)
            if model.friends.isEmpty {
                Text(model.t.friendsTip)
                    .font(.caption)
                    .foregroundStyle(Brand.muted)
            } else {
                let anyGroup = model.groups.contains { model.isGroupChosen($0) }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        PickChip(label: model.t.everyone, selected: model.services.isEmpty, action: { model.pick([]); copied = false }, leadingPadding: 14) { EmptyView() }
                        ForEach(model.groups, id: \.self) { group in
                            PickChip(label: group.name, selected: model.isGroupChosen(group), action: { model.toggle(group: group); copied = false }) {
                                Text("\(group.members.count)")
                                    .font(.caption)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(Brand.raised))
                                    .accessibilityHidden(true)
                            }
                        }
                        ForEach(model.friends, id: \.self) { friend in
                            PickChip(label: friend.name, selected: model.chosen.contains(friend.name) && !anyGroup, action: { model.toggle(friend.name); copied = false }) {
                                FriendAvatar(friend: friend)
                            }
                            .accessibilityLabel("\(friend.name), \(ShareModel.platforms[friend.platform] ?? friend.platform)")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // All services, tapping one adds or removes its link from the message
    private func tiles(_ song: Song) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(ShareModel.servicesFor(song.source.kind), id: \.self) { platform in
                let selected = model.services.contains(platform)
                let name = ShareModel.serviceName(platform, song.source.kind)
                Button {
                    model.toggle(service: platform)
                    copied = false
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        ServiceLogo(platform: platform, kind: song.source.kind, size: 26)
                        Text(name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                            .padding(.trailing, 18)
                        Text(model.detail(platform))
                            .font(.caption)
                            .foregroundStyle(Brand.muted)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(selected ? Brand.raised : Color.white.opacity(0.03)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(selected ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Brand.hairlineStrong), lineWidth: selected ? 1.5 : 1)
                    )
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Brand.accent)
                                .padding(10)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(name), \(model.detail(platform))")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var hint: String {
        // A friend's service without podcasts leaves the message, see friendsMessage
        let kind = model.song?.source.kind ?? "song"
        let shown = model.services.filter(ShareModel.servicesFor(kind).contains)
        guard let first = shown.first else { return model.t.hintEveryone }
        if shown.count > 1 { return model.t.hintSeveral }
        return model.t.hintOne(ShareModel.serviceName(first, kind), model.me != nil)
    }

    private func messageBox(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(hint)
                .font(.caption)
                .foregroundStyle(Brand.muted)
            Text(message)
                .font(.footnote)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.25)))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Brand.hairline))
    }

    private func actions(_ message: String) -> some View {
        HStack(spacing: 8) {
            Button {
                shareItem = SharedItem(items: [message])
            } label: {
                Label(model.t.share, systemImage: "square.and.arrow.up")
            }
            .buttonStyle(MainButtonStyle())
            Button {
                UIPasteboard.general.string = message
                copied = true
                sent()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { finish() }
            } label: {
                Label(copied ? model.t.copied : model.t.copy, systemImage: "doc.on.doc")
            }
            .buttonStyle(GhostButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Brand.background.opacity(0.92))
    }
}

// Pill buttons like the app: the gradient only on the main action
private struct MainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Brand.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 18)
            .background(Capsule().fill(Brand.gradient))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

private struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Brand.text)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 18)
            .contentShape(Capsule())
            .overlay(Capsule().strokeBorder(Brand.hairlineStrong))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

private struct SharedItem: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    let completion: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            DispatchQueue.main.async { completion(completed) }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
