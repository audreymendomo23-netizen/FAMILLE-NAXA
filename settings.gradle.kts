pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral(); maven { url = uri("https://jitpack.io"); content { includeGroupByRegex("com\\.github\\..*") } } } }
rootProject.name = "FamilleNAXA"
include(":core-android", ":kiosko", ":bootik", ":zipple", ":naxa-services", ":cotiz", ":loyable", ":naxa-hotel", ":campus237", ":naxa-security", ":grillad")

project(":kiosko").projectDir = file("apps/android/kiosko")
project(":bootik").projectDir = file("apps/android/bootik")
project(":zipple").projectDir = file("apps/android/zipple")
project(":naxa-services").projectDir = file("apps/android/naxa-services")
project(":cotiz").projectDir = file("apps/android/cotiz")
project(":loyable").projectDir = file("apps/android/loyable")
project(":naxa-hotel").projectDir = file("apps/android/naxa-hotel")
project(":campus237").projectDir = file("apps/android/campus237")
project(":naxa-security").projectDir = file("apps/android/naxa-security")
project(":grillad").projectDir = file("apps/android/grillad")
project(":core-android").projectDir = file("packages/core-android")
include(":widemeet")
project(":widemeet").projectDir = file("apps/android/widemeet")
