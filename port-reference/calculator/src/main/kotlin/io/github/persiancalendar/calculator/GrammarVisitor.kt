package io.github.persiancalendar.calculator

import io.github.persiancalendar.calculator.parser.GrammarBaseVisitor
import io.github.persiancalendar.calculator.parser.GrammarParser

class GrammarVisitor(private val defaultValues: Map<String, Value>) : GrammarBaseVisitor<Value>() {
    private val clearFunction = Value.Function({
        registry = defaultValues.toMutableMap().also(::addClear)
        Value.Null
    }, 0)
    private var registry = defaultValues.toMutableMap().also(::addClear)

    private fun addClear(map: MutableMap<String, Value>) {
        map["clear"] = clearFunction
    }

    override fun visitAssign(ctx: GrammarParser.AssignContext): Value {
        registry[ctx.SYMBOL().text] = visit(ctx.expression())
        return Value.Null
    }

    override fun visitProgram(ctx: GrammarParser.ProgramContext): Value {
        return Value.Tuple(
            ctx.children?.mapNotNull(::visit)?.filter { it !is Value.Null } ?: emptyList()
        )
    }

    override fun visitPrintExpression(ctx: GrammarParser.PrintExpressionContext): Value {
        val value = visit(ctx.expression())
        return if (value is Value.Function && value.inputCount == 0) value(emptyList()) else value
    }

    override fun visitSignedAtom(ctx: GrammarParser.SignedAtomContext): Value {
        return if (ctx.childCount == 2 && ctx.children[0].text == "-")
            Value.Number(-1.0) * visit(ctx.signedAtom())
        else super.visitSignedAtom(ctx)
    }

    override fun visitNumber(ctx: GrammarParser.NumberContext): Value {
        return Value.Number(ctx.NUMBER().text.toDouble())
    }

    override fun visitSymbol(ctx: GrammarParser.SymbolContext): Value {
        val symbol = ctx.SYMBOL().text
        return registry[symbol] ?: Value.Symbol(symbol)
    }

    override fun visitExponentialExpression(
        ctx: GrammarParser.ExponentialExpressionContext
    ): Value {
        return ctx.signedAtom().map(::visit).reduceRight { x, y -> x.pow(y) }
    }

    override fun visitMultiplicativeExpression(
        ctx: GrammarParser.MultiplicativeExpressionContext
    ): Value {
        return ctx.exponentialExpression().map(::visit).reduceIndexed { i, x, y ->
            when (ctx.getChild((i - 1) * 2 + 1).text) {
                "*" -> x * y
                "/" -> x / y
                "%" -> x % y
                else -> error("Unexpected operator")
            }
        }
    }

    override fun visitAdditiveExpression(ctx: GrammarParser.AdditiveExpressionContext): Value {
        return ctx.multiplicativeExpression().map(::visit).reduceIndexed { i, x, y ->
            when (ctx.getChild((i - 1) * 2 + 1).text) {
                "+" -> x + y
                "-" -> x - y
                else -> error("Unexpected operator")
            }
        }
    }

    override fun visitParenthesizedExpression(
        ctx: GrammarParser.ParenthesizedExpressionContext
    ): Value {
        val tuple = ctx.expression().map(::visit)
        return if (tuple.size == 1) tuple[0] else Value.Tuple(tuple)
    }

    override fun visitCall(ctx: GrammarParser.CallContext): Value {
        val callSeries = ctx.atom().map(::visit)
        val pairs = callSeries.takeIf { it.size % 2 == 0 }?.chunked(2)
        if (pairs?.all { (x, y) -> x is Value.Number && y is Value.Symbol } == true)
            return pairs
                .map { (x, y) -> (x as Value.Number) withUnit (y as Value.Symbol) }
                .reduce { acc, x -> (acc + x) as Value.Number }
        return callSeries.reduceRight { x, y -> // This should be a left reduce probably
            when (x) {
                is Value.Function -> x(if (y is Value.Tuple) y.values else listOf(y))
                is Value.Number ->
                    if (y is Value.Symbol) x withUnit y else error("Not supported number call")
                else -> error("Not supported call")
            }
        }
    }
}
