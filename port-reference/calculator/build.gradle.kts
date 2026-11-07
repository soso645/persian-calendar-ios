import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    java
    antlr
    kotlin("jvm") version "2.3.0"
    `maven-publish`
}

group = "io.github.persiancalendar"
version = "0.0.1"

repositories {
    mavenCentral()
}

dependencies {
    antlr("org.antlr:antlr4:4.13.2")
    implementation("org.antlr:antlr4-runtime:4.13.2")
    testImplementation(kotlin("test"))
    val junit5Version = "6.0.0"
    testImplementation("org.junit.jupiter:junit-jupiter-api:$junit5Version")
    testImplementation("org.junit.jupiter:junit-jupiter-params:$junit5Version")
    testRuntimeOnly("org.junit.jupiter:junit-jupiter-engine:$junit5Version")
}

// https://github.com/gradle/gradle/issues/820#issuecomment-808315335
configurations[JavaPlugin.API_CONFIGURATION_NAME].let { apiConfiguration ->
    apiConfiguration.setExtendsFrom(apiConfiguration.extendsFrom.filter { it.name != "antlr" })
}

tasks.generateGrammarSource {
    maxHeapSize = "64m"
    arguments = arguments + listOf("-no-listener", "-visitor", "-package", "io.github.persiancalendar.calculator.parser")
    outputDirectory =
        File("${project.layout.buildDirectory.get()}/generated-src/antlr/main/io/github/persiancalendar/calculator/parser")
}
tasks.named("compileKotlin").configure { dependsOn(tasks.generateGrammarSource) }

tasks.test {
    useJUnitPlatform()
}

kotlin {
    jvmToolchain(21)
    compilerOptions { jvmTarget = JvmTarget.JVM_21 }
}

val sourceJar by tasks.registering(Jar::class) {
    dependsOn(tasks["classes"])
    archiveClassifier.set("sources")
    from(sourceSets["main"].allSource)
}

publishing {
    publications {
        register("mavenJava", MavenPublication::class) {
            from(components["kotlin"])
            artifact(sourceJar)
        }
    }
}
