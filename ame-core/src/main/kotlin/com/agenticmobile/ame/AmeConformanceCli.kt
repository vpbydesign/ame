package com.agenticmobile.ame

import kotlin.system.exitProcess

fun main(args: Array<String>) {
    if (args.isEmpty()) {
        System.err.println("Usage: ame-conformance <file.ame>")
        exitProcess(1)
    }
    val input = java.io.File(args[0]).readText()
    val parser = AmeParser()
    val tree = parser.parse(input) ?: run {
        System.err.println("Parse returned null")
        exitProcess(2)
    }
    println(AmeSerializer.toJson(tree))
}
