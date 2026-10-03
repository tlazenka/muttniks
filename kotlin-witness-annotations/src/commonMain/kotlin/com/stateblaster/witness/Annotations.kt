package com.stateblaster.witness

import kotlin.reflect.KClass

@Target(AnnotationTarget.CLASS) annotation class StateGraph

@Target(AnnotationTarget.CLASS) annotation class StateMachine

@Target(AnnotationTarget.CLASS) annotation class ComposeNavigation3

@Target(AnnotationTarget.CLASS) annotation class Initial

@Target(AnnotationTarget.CLASS) @Repeatable annotation class Transition(val destination: KClass<*>)

@Target(AnnotationTarget.CLASS) annotation class LinearCapability

@Target(AnnotationTarget.VALUE_PARAMETER) annotation class Consumes

@Target(AnnotationTarget.CLASS) annotation class KtorService(val path: String)

@Target(AnnotationTarget.CLASS) annotation class Operation(val name: String, val input: KClass<*>)

@Target(AnnotationTarget.CLASS) annotation class KtorServer

@Target(AnnotationTarget.CLASS) annotation class KtorClient
