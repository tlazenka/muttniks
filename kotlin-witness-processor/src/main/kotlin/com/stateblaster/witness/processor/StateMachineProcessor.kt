package com.stateblaster.witness.processor

import com.google.devtools.ksp.processing.*
import com.google.devtools.ksp.symbol.*
import com.google.devtools.ksp.validate

class StateMachineProcessorProvider : SymbolProcessorProvider {
    override fun create(environment: SymbolProcessorEnvironment): SymbolProcessor {
        return CompositeWitnessProcessor(
            StateMachineProcessor(environment.codeGenerator, environment.logger),
            KtorProjectionProcessor(environment.codeGenerator, environment.logger),
        )
    }
}

private class CompositeWitnessProcessor(
    private vararg val processors: SymbolProcessor,
) : SymbolProcessor {
    override fun process(resolver: Resolver): List<KSAnnotated> =
        processors.flatMap { it.process(resolver) }.distinct()

    override fun finish() {
        processors.forEach { it.finish() }
    }

    override fun onError() {
        processors.forEach { it.onError() }
    }
}

private data class Field(val name: String, val type: String)

private data class State(
    val name: String,
    val qualifiedName: String,
    val fields: List<Field>,
    val transitions: List<String>,
    val initial: Boolean,
)

class StateMachineProcessor(
    private val codeGenerator: CodeGenerator,
    private val logger: KSPLogger,
) : SymbolProcessor {
    private val generated = mutableSetOf<String>()

    override fun process(resolver: Resolver): List<KSAnnotated> {
        val symbols = resolver.getSymbolsWithAnnotation("com.stateblaster.witness.StateMachine")
        val deferred = symbols.filterNot { it.validate() }.toList()
        symbols
            .filterIsInstance<KSClassDeclaration>()
            .filter { it.validate() }
            .forEach { decl ->
                val qn = decl.qualifiedName?.asString() ?: return@forEach
                if (generated.add(qn)) generate(decl)
            }
        return deferred
    }

    private fun KSAnnotated.hasAnnotation(qn: String) = annotations.any {
        it.annotationType.resolve().declaration.qualifiedName?.asString() == qn
    }

    private fun generate(machine: KSClassDeclaration) {
        val pkg = machine.packageName.asString()
        val machineName = machine.simpleName.asString()
        val states =
            machine.declarations
                .filterIsInstance<KSClassDeclaration>()
                .map { s ->
                    val transitions =
                        s.annotations
                            .filter {
                                it.annotationType.resolve().declaration.qualifiedName?.asString() ==
                                    "com.stateblaster.witness.Transition"
                            }
                            .mapNotNull { a ->
                                val v = a.arguments.firstOrNull()?.value
                                (v as? KSType)?.declaration?.simpleName?.asString()
                            }
                            .toList()
                    val fields =
                        s.primaryConstructor?.parameters?.mapNotNull { p ->
                            val n = p.name?.asString() ?: return@mapNotNull null
                            Field(
                                n,
                                p.type.resolve().declaration.qualifiedName?.asString()
                                    ?: p.type.resolve().toString(),
                            )
                        } ?: emptyList()
                    State(
                        s.simpleName.asString(),
                        s.qualifiedName!!.asString(),
                        fields,
                        transitions,
                        s.hasAnnotation("com.stateblaster.witness.Initial"),
                    )
                }
                .toList()

        val initial =
            states.singleOrNull { it.initial }
                ?: run {
                    logger.error("$machineName needs exactly one @Initial state", machine)
                    return
                }
        writeMachine(pkg, machineName, states, initial)
        if (machine.hasAnnotation("com.stateblaster.witness.ComposeNavigation3"))
            writeNavigation(pkg, machineName, states, initial)
    }

    private fun stateType(machine: String, s: State) = "$machine.${s.name}"

    private fun params(s: State) = s.fields.joinToString(", ") { "${it.name}: ${it.type}" }

    private fun args(s: State) = s.fields.joinToString(", ") { it.name }

    private fun construct(machine: String, s: State): String =
        if (s.fields.isEmpty()) "$machine.${s.name}" else "$machine.${s.name}(${args(s)})"

    private fun writeMachine(pkg: String, machine: String, states: List<State>, initial: State) {
        val name = machine.removeSuffix("State") + "Machine"
        val byName = states.associateBy { it.name }
        val methods = buildString {
            states.forEach { src ->
                src.transitions.forEach { destName ->
                    val dest = byName[destName] ?: return@forEach
                    appendLine(
                        """
    fun authorize${src.name}To$destName(witness: Witness<$machine.${src.name}>): TransitionAuthority<$machine.${src.name}, $machine.$destName>? {
        return generatedAuthorize(witness)
    }
"""
                    )
                    appendLine(
                        """
    fun transition${src.name}To$destName(${params(dest)}${if(dest.fields.isNotEmpty()) ", " else ""}using: TransitionAuthority<$machine.${src.name}, $machine.$destName>): Boolean {
        install(${construct(machine, dest)})
        return true
    }
"""
                    )
                }
            }
        }
        val witnessCases =
            states.joinToString("\n") { s ->
                """    fun ${s.name.replaceFirstChar { it.lowercase() }}Witness(): Witness<$machine.${s.name}>? =
        (state as? $machine.${s.name})?.let { generatedWitness(it) }"""
            }
        val initialExpr = construct(machine, initial)
        wGenerated(
            pkg,
            "$name.kt",
            """
package $pkg
import com.stateblaster.witness.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class $name private constructor(initial: $machine) {
    private val mutableStates = MutableStateFlow(initial)
    val states: StateFlow<$machine> = mutableStates.asStateFlow()
    val state: $machine get() = mutableStates.value
    private fun install(next: $machine) { mutableStates.value = next }

$witnessCases
$methods
    companion object {
        fun initialState(): $name = $name($initialExpr)
    }
}
""",
        )
    }

    private fun writeNavigation(pkg: String, machine: String, states: List<State>, initial: State) {
        val base = machine.removeSuffix("State")
        val machineClass = "${base}Machine"
        val byName = states.associateBy { it.name }
        val keyCases =
            states.joinToString("\n") { s ->
                if (s.fields.isEmpty()) "    data object ${s.name} : ${base}NavKey"
                else
                    "    data class ${s.name}(${s.fields.joinToString(", ") { "val ${it.name}: ${it.type}" }}) : ${base}NavKey"
            }
        val toKey =
            states.joinToString("\n") { s ->
                if (s.fields.isEmpty()) "        $machine.${s.name} -> ${base}NavKey.${s.name}"
                else
                    "        is $machine.${s.name} -> ${base}NavKey.${s.name}(${s.fields.joinToString(", ") { "state.${it.name}" }})"
            }
        val scopes =
            states.joinToString("\n\n") { src ->
                val edgeMethods =
                    src.transitions.joinToString("\n") { dname ->
                        val dest = byName.getValue(dname)
                        val fn = dname.replaceFirstChar { it.lowercase() }
                        """    fun $fn(${params(dest)}): Boolean {
        val witness = machine.${src.name.replaceFirstChar { it.lowercase() }}Witness() ?: return false
        val authority = machine.authorize${src.name}To$dname(witness) ?: return false
        return machine.transition${src.name}To$dname(${args(dest)}${if(dest.fields.isNotEmpty()) ", " else ""}using = authority)
    }"""
                    }
                """class ${src.name}Scope internal constructor(
    internal val machine: $machineClass,
    val state: $machine.${src.name}
) {
$edgeMethods
}"""
            }
        val screenProps =
            states.joinToString(",\n") { s ->
                "    val ${s.name.replaceFirstChar { it.lowercase() }}: @Composable (${s.name}Scope) -> Unit"
            }
        val entries =
            states.joinToString("\n") { s ->
                """        entry<${base}NavKey.${s.name}> {
            val current = machine.state as? $machine.${s.name} ?: return@entry
            screens.${s.name.replaceFirstChar { it.lowercase() }}(${s.name}Scope(machine, current))
        }"""
            }
        wGenerated(
            pkg,
            "${base}Navigation.kt",
            """
package $pkg

import androidx.compose.runtime.*
import androidx.navigation3.runtime.NavKey
import androidx.navigation3.runtime.entryProvider
import androidx.navigation3.ui.NavDisplay
import kotlinx.coroutines.flow.collectLatest

sealed interface ${base}NavKey : NavKey {
$keyCases
}

fun $machine.toNavKey(): ${base}NavKey = when (val state = this) {
$toKey
}

$scopes

class ${base}Screens(
$screenProps
)

@Composable
fun ${base}Navigation(machine: $machineClass, screens: ${base}Screens) {
    val state by machine.states.collectAsState()
    val backStack = remember { mutableStateListOf<${base}NavKey>(state.toNavKey()) }

    LaunchedEffect(state) {
        val key = state.toNavKey()
        if (backStack.lastOrNull() != key) backStack.add(key)
    }

    NavDisplay(
        backStack = backStack,
        onBack = {
            val current = machine.state
            when (current) {
${states.mapNotNull { s ->
    val reverse = s.transitions.singleOrNull()?.let { d -> byName[d] } ?: return@mapNotNull null
    val fn=reverse.name.replaceFirstChar { it.lowercase() }
    """                is $machine.${s.name} -> {
                    val scope = ${s.name}Scope(machine, current)
                    if (scope.$fn(${reverse.fields.joinToString(", ") { f ->
                        if (s.fields.any { it.name == f.name }) "current.${f.name}"
                        else defaultFor(f.type)
                    }})) backStack.removeLastOrNull()
                }"""
}.joinToString("\n")}
                else -> Unit
            }
        },
        entryProvider = entryProvider {
$entries
        }
    )
}
""",
        )
    }

    private fun defaultFor(type: String) =
        when (type) {
            "kotlin.String" -> "\"\""
            "kotlin.Int" -> "0"
            "kotlin.Boolean" -> "false"
            else -> "error(\"type: $type\")"
        }

    private fun wGenerated(pkg: String, file: String, body: String) {
        val out =
            codeGenerator.createNewFile(
                Dependencies(false),
                pkg,
                file.removeSuffix(".kt"),
            )
        out.writer().use { it.write(textwrap(body)) }
    }

    private fun textwrap(s: String) = s.trimIndent() + "\n"
}

private data class KtorField(val name: String, val type: String)

private data class KtorState(
    val name: String,
    val fields: List<KtorField>,
    val successors: List<String>,
)

private data class OperationModel(
    val name: String,
    val inputType: String,
    val source: KtorState,
    val successors: List<KtorState>,
)

private class KtorProjectionProcessor(
    private val codeGenerator: CodeGenerator,
    private val logger: KSPLogger,
) : SymbolProcessor {
    private val generated = mutableSetOf<String>()

    override fun process(resolver: Resolver): List<KSAnnotated> {
        val symbols =
            resolver.getSymbolsWithAnnotation("com.stateblaster.witness.KtorService").toList()
        val deferred = symbols.filterNot { it.validate() }
        symbols
            .filterIsInstance<KSClassDeclaration>()
            .filter { it.validate() }
            .forEach { machine ->
                val qn = machine.qualifiedName?.asString() ?: return@forEach
                if (generated.add(qn)) generate(machine)
            }
        return deferred
    }

    private fun KSAnnotated.annotation(qn: String): KSAnnotation? = annotations.firstOrNull {
        it.annotationType.resolve().declaration.qualifiedName?.asString() == qn
    }

    private fun KSAnnotation.stringArgument(name: String): String {
        val value = arguments.firstOrNull { it.name?.asString() == name }?.value
        return value as? String
            ?: error(
                "Missing String annotation argument '$name'; received ${value?.let { it::class.qualifiedName }}"
            )
    }

    private fun KSAnnotation.typeArgument(name: String): KSType {
        val value = arguments.firstOrNull { it.name?.asString() == name }?.value
        return value as? KSType
            ?: error(
                "Expected KSType for annotation argument '$name'; received ${value?.let { it::class.qualifiedName }}"
            )
    }

    private fun generate(machine: KSClassDeclaration) {
        val pkg = machine.packageName.asString()
        val base = machine.simpleName.asString().removeSuffix("State")
        val path =
            machine
                .annotation("com.stateblaster.witness.KtorService")
                ?.arguments
                ?.firstOrNull { it.name?.asString() == "path" }
                ?.value as? String ?: return

        val declarations = machine.declarations.filterIsInstance<KSClassDeclaration>().toList()
        val states = declarations.associate { d ->
            val fields =
                d.primaryConstructor?.parameters?.mapNotNull { p ->
                    val name = p.name?.asString() ?: return@mapNotNull null
                    KtorField(
                        name,
                        p.type.resolve().declaration.qualifiedName?.asString()
                            ?: p.type.resolve().toString(),
                    )
                } ?: emptyList()
            val successors =
                d.annotations
                    .filter {
                        it.annotationType.resolve().declaration.qualifiedName?.asString() ==
                            "com.stateblaster.witness.Transition"
                    }
                    .mapNotNull {
                        (it.arguments.firstOrNull()?.value as? KSType)
                            ?.declaration
                            ?.simpleName
                            ?.asString()
                    }
                    .toList()
            d.simpleName.asString() to KtorState(d.simpleName.asString(), fields, successors)
        }

        val operations = declarations.mapNotNull { d ->
            val a = d.annotation("com.stateblaster.witness.Operation") ?: return@mapNotNull null
            val name = a.stringArgument("name")
            val inputType = a.typeArgument("input")
            val input =
                inputType.declaration as? KSClassDeclaration
                    ?: error("@Operation input must be a class: $inputType")
            val inputName =
                input.qualifiedName?.asString()
                    ?: error("@Operation input must have a qualified name")
            val source = states.getValue(d.simpleName.asString())
            OperationModel(
                name,
                inputName,
                source,
                source.successors.mapNotNull(states::get),
            )
        }

        if (operations.isEmpty()) {
            logger.error(
                "@KtorService ${machine.qualifiedName?.asString()} has no @Operation declarations",
                machine,
            )
            return
        }

        emitProtocol(pkg, base, path, operations)
        if (machine.annotation("com.stateblaster.witness.KtorServer") != null) {
            emitServer(pkg, base, path, operations)
        }
        if (machine.annotation("com.stateblaster.witness.KtorClient") != null) {
            emitClient(pkg, base, path, operations)
            if (machine.annotation("com.stateblaster.witness.ComposeNavigation3") != null) {
                emitRemoteTransitions(pkg, base, operations)
            }
        }
    }

    private fun emitProtocol(pkg: String, base: String, path: String, ops: List<OperationModel>) {
        val source = buildString {
            appendLine("package $pkg")
            appendLine("import kotlinx.serialization.Serializable")
            appendLine("import kotlinx.serialization.SerialName")
            ops.forEach { op ->
                val cap = op.name.replaceFirstChar(Char::uppercase)
                appendLine("@Serializable sealed interface ${cap}Response {")
                op.successors.forEach { r ->
                    if (r.fields.isEmpty()) {
                        appendLine("  @Serializable")
                        appendLine("  @SerialName(\"${r.name.replaceFirstChar(Char::lowercase)}\")")
                        appendLine("  data object ${r.name} : ${cap}Response")
                    } else {
                        appendLine("  @Serializable")
                        appendLine("  @SerialName(\"${r.name.replaceFirstChar(Char::lowercase)}\")")
                        appendLine(
                            "  data class ${r.name}(" +
                                r.fields.joinToString(", ") { "val ${it.name}: ${it.type}" } +
                                ") : ${cap}Response"
                        )
                    }
                }
                appendLine("}")
            }
            appendLine("interface ${base}Service {")
            ops.forEach { op ->
                val cap = op.name.replaceFirstChar(Char::uppercase)
                appendLine("  suspend fun ${op.name}(request: ${op.inputType}): ${cap}Response")
            }
            appendLine("}")
        }
        output(pkg, "${base}Protocol", source)
    }

    private fun emitRemoteTransitions(
        pkg: String,
        base: String,
        ops: List<OperationModel>,
    ) {
        val source = buildString {
            appendLine("package $pkg")
            ops.forEach { op ->
                val cap = op.name.replaceFirstChar(Char::uppercase)
                val scopeType = "${op.source.name}Scope"
                appendLine("fun ${cap}Response.applyTo(scope: $scopeType) {")
                appendLine("  when (this) {")
                op.successors.forEach { result ->
                    val transition = result.name.replaceFirstChar(Char::lowercase)
                    val args = result.fields.joinToString(", ") { "this.${it.name}" }
                    if (args.isEmpty()) {
                        appendLine("    ${cap}Response.${result.name} -> scope.$transition()")
                    } else {
                        appendLine(
                            "    is ${cap}Response.${result.name} -> scope.$transition($args)"
                        )
                    }
                }
                appendLine("  }")
                appendLine("}")
            }
        }
        output(pkg, "${base}RemoteTransitions", source)
    }

    // TODO: may want option to disable cURL output
    private fun emitClient(pkg: String, base: String, path: String, ops: List<OperationModel>) {
        val source = buildString {
            appendLine("package $pkg")
            appendLine("import io.ktor.client.HttpClient")
            appendLine("import io.ktor.client.call.body")
            appendLine("import io.ktor.client.request.*")
            appendLine("import io.ktor.client.plugins.contentnegotiation.ContentNegotiation")
            appendLine("import io.ktor.serialization.kotlinx.json.json")
            appendLine("import io.ktor.http.*")
            appendLine("import kotlinx.serialization.encodeToString")
            appendLine("import kotlinx.serialization.json.Json")
            appendLine(
                "class ${base}Client(private val http: HttpClient, private val baseUrl: String = \"\", private val _json: Json = Json { classDiscriminator = \"type\" }) {"
            )
            ops.forEach { op ->
                val cap = op.name.replaceFirstChar(Char::uppercase)
                val route = op.name.removePrefix("submit").replaceFirstChar(Char::lowercase)
                appendLine(
                    """  suspend fun ${op.name}(request: ${op.inputType}): ${cap}Response {
    val url = baseUrl + "$path/$route"
    val jsonBody = _json.encodeToString(request)
    println("cURL: curl -X POST -H 'Content-Type: application/json' --data '${'$'}jsonBody' '${'$'}url'")
    return http.post(url) {
      contentType(ContentType.Application.Json)
      setBody(request)
    }.body()
  }"""
                )
            }
            appendLine("}")
        }
        output(pkg, "${base}KtorClient", source)
    }

    private fun emitServer(pkg: String, base: String, path: String, ops: List<OperationModel>) {
        val source = buildString {
            appendLine("package $pkg")
            appendLine("import io.ktor.server.request.receive")
            appendLine("import io.ktor.server.response.respond")
            appendLine("import io.ktor.server.routing.*")
            appendLine(
                "fun Route.${base.replaceFirstChar(Char::lowercase)}Routes(service: ${base}Service) { route(\"$path\") {"
            )
            ops.forEach { op ->
                val cap = op.name.replaceFirstChar(Char::uppercase)
                val route = op.name.removePrefix("submit").replaceFirstChar(Char::lowercase)
                appendLine(
                    """  post("/$route") {
    val request = call.receive<${op.inputType}>()
    call.respond(service.${op.name}(request))
  }"""
                )
            }
            appendLine("}}")
        }
        output(pkg, "${base}KtorServer", source)
    }

    private fun output(pkg: String, name: String, source: String) {
        codeGenerator.createNewFile(Dependencies(false), pkg, name).writer().use {
            it.write(source)
        }
    }
}
