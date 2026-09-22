#!/usr/bin/env python3

import argparse
import re
import sys

TEXT_BASE = 0x00000000
DATA_BASE = 0x10000000

REG_ALIAS = {
    "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4,
    "t0": 5, "t1": 6, "t2": 7, "s0": 8, "fp": 8, "s1": 9,
    "a0": 10, "a1": 11, "a2": 12, "a3": 13, "a4": 14, "a5": 15,
    "a6": 16, "a7": 17,
    "s2": 18, "s3": 19, "s4": 20, "s5": 21, "s6": 22, "s7": 23,
    "s8": 24, "s9": 25, "s10": 26, "s11": 27,
    "t3": 28, "t4": 29, "t5": 30, "t6": 31,
}
for _i in range(32):
    REG_ALIAS[f"x{_i}"] = _i


def reg(tok):
    t = tok.strip().lower()
    if t not in REG_ALIAS:
        raise AsmError(f"unknown register '{tok}'")
    return REG_ALIAS[t]


class AsmError(Exception):
    pass


def die(msg, fname, line):
    sys.stderr.write(f"{fname}:{line}: error: {msg}\n")
    sys.exit(1)


NUM_RE = re.compile(r"0[xX][0-9a-fA-F]+|0[bB][01]+|\d+")


class ExprParser:
    def __init__(self, text, symbols, line_info):
        self.toks = self._lex(text)
        self.pos = 0
        self.symbols = symbols
        self.line_info = line_info

    def _lex(self, s):
        toks = []
        i = 0
        while i < len(s):
            c = s[i]
            if c.isspace():
                i += 1
            elif s.startswith("%hi", i) or s.startswith("%lo", i):
                toks.append(s[i:i + 3])
                i += 3
            elif c in "+-*/(),":
                toks.append(c)
                i += 1
            else:
                m = NUM_RE.match(s, i)
                if m:
                    toks.append(m.group())
                    i = m.end()
                else:
                    m = re.compile(r"[A-Za-z_.$][A-Za-z0-9_.$]*").match(s, i)
                    if m:
                        toks.append(m.group())
                        i = m.end()
                    else:
                        raise AsmError(f"bad character '{c}' in expression")
        toks.append("<eof>")
        return toks

    def peek(self):
        return self.toks[self.pos]

    def next(self):
        t = self.toks[self.pos]
        self.pos += 1
        return t

    def parse(self):
        v = self.expr()
        if self.peek() != "<eof>":
            raise AsmError(f"trailing junk in expression near '{self.peek()}'")
        return v

    def expr(self):
        v = self.term()
        while self.peek() in ("+", "-", "*"):
            op = self.next()
            r = self.term()
            if op == "+":
                v += r
            elif op == "-":
                v -= r
            else:
                v *= r
        return v

    def term(self):
        t = self.peek()
        if t == "-":
            self.next()
            return -self.term()
        if t == "(":
            self.next()
            v = self.expr()
            if self.next() != ")":
                raise AsmError("missing ')'")
            return v
        if t in ("%hi", "%lo"):
            self.next()
            if self.next() != "(":
                raise AsmError(f"{t} needs parentheses: {t}(expr)")
            v = self.expr()
            if self.next() != ")":
                raise AsmError("missing ')'")
            v &= 0xFFFFFFFF
            if t == "%hi":
                return ((v + 0x800) >> 12) & 0xFFFFF
            return v & 0xFFF
        if t == "<eof>":
            raise AsmError("unexpected end of expression")
        self.next()
        if NUM_RE.fullmatch(t):
            return int(t, 0)
        if t in self.symbols:
            return self.symbols[t]
        raise AsmError(f"undefined symbol '{t}'")


def eval_expr(text, symbols, line_info):
    try:
        return ExprParser(text, symbols, line_info).parse()
    except AsmError as e:
        die(str(e), *line_info)


def try_eval(text, symbols, line_info):
    try:
        return ExprParser(text, symbols, line_info).parse()
    except AsmError:
        return None


def enc_r(funct7, rs2, rs1, funct3, rd, opcode):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def enc_i(imm, rs1, funct3, rd, opcode):
    imm &= 0xFFF
    return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def enc_s(imm, rs2, rs1, funct3, opcode):
    imm &= 0xFFF
    return (((imm >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | \
           ((imm & 0x1F) << 7) | opcode


def enc_b(imm, rs2, rs1, funct3, opcode):
    imm &= 0x1FFF
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | \
           (rs1 << 15) | (funct3 << 12) | (((imm >> 1) & 0xF) << 8) | \
           (((imm >> 11) & 1) << 7) | opcode


def enc_u(imm, rd, opcode):
    return ((imm & 0xFFFFF) << 12) | (rd << 7) | opcode


def enc_j(imm, rd, opcode):
    imm &= 0x1FFFFF
    return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | \
           (((imm >> 11) & 1) << 20) | (((imm >> 12) & 0xFF) << 12) | (rd << 7) | opcode


OPC_LOAD, OPC_OPIMM, OPC_AUIPC = 0b0000011, 0b0010011, 0b0010111
OPC_STORE, OPC_OP, OPC_LUI = 0b0100011, 0b0110011, 0b0110111
OPC_BRANCH, OPC_JALR, OPC_JAL = 0b1100011, 0b1100111, 0b1101111
OPC_SYSTEM, OPC_CUSTOM0 = 0b1110011, 0b0001011

R_OPS = {
    "add": (0x00, 0), "sub": (0x20, 0), "sll": (0x00, 1), "slt": (0x00, 2),
    "sltu": (0x00, 3), "xor": (0x00, 4), "srl": (0x00, 5), "sra": (0x20, 5),
    "or": (0x00, 6), "and": (0x00, 7), "mul": (0x01, 0),
}
I_OPS = {
    "addi": (0, 0), "slti": (2, 0), "sltiu": (3, 0), "xori": (4, 0),
    "ori": (6, 0), "andi": (7, 0), "slli": (1, 1), "srli": (5, 1), "srai": (5, 1),
}
B_OPS = {"beq": 0, "bne": 1, "blt": 4, "bge": 5, "bltu": 6, "bgeu": 7}


def imm_check_signed(v, bits, what, line_info):
    lo, hi = -(1 << (bits - 1)), (1 << (bits - 1)) - 1
    if not (lo <= v <= hi):
        raise AsmError(f"{what} {v} does not fit in {bits} signed bits")


def lui_lo(v):
    v &= 0xFFFFFFFF
    hi = ((v + 0x800) >> 12) & 0xFFFFF
    lo = v & 0xFFF
    if lo >= 0x800:
        lo -= 0x1000
    return hi, lo


def split_args(rest):
    out, depth, cur, in_str = [], 0, "", False
    for c in rest:
        if in_str:
            cur += c
            if c == '"':
                in_str = False
        elif c == '"':
            in_str = True
            cur += c
        elif c == "(":
            depth += 1
            cur += c
        elif c == ")":
            depth -= 1
            cur += c
        elif c == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            cur += c
    if cur.strip() or out:
        out.append(cur.strip())
    return out


MEM_OPERAND = re.compile(r"^(.*?)\(\s*([A-Za-z0-9]+)\s*\)$")


def parse_mem(tok, symbols, line_info):
    m = MEM_OPERAND.match(tok.strip())
    if not m:
        raise AsmError(f"bad memory operand '{tok}' (expected off(reg))")
    off_s, r_s = m.group(1).strip(), m.group(2)
    off = 0 if off_s == "" else eval_expr(off_s, symbols, line_info)
    return off, reg(r_s)


class Assembler:
    def __init__(self):
        self.symbols = {}
        self.items = []
        self.section = "text"
        self.off = {"text": 0, "data": 0}
        self.fname = ""
        self.line = 0

    def feed(self, raw, fname, line):
        self.fname, self.line = fname, line
        info = (fname, line)
        s = raw.split("#")[0].split("//")[0].strip()
        if not s:
            return
        while True:
            m = re.match(r"^([A-Za-z_.$][A-Za-z0-9_.$]*)\s*:\s*(.*)$", s)
            if not m:
                break
            lab, s = m.group(1), m.group(2).strip()
            base = TEXT_BASE if self.section == "text" else DATA_BASE
            if lab in self.symbols:
                raise AsmError(f"duplicate label '{lab}'")
            self.symbols[lab] = base + self.off[self.section]
        if not s:
            return
        if s.startswith("."):
            self.directive(s, info)
        else:
            self.instruction(s, info)

    def directive(self, s, info):
        parts = s.split(None, 1)
        d = parts[0].lower()
        rest = parts[1] if len(parts) > 1 else ""
        if d == ".text":
            self.section = "text"
        elif d == ".data":
            self.section = "data"
        elif d == ".org":
            self.off[self.section] = eval_expr(rest, self.symbols, info)
        elif d == ".equ":
            args = split_args(rest)
            if len(args) != 2:
                raise AsmError(".equ needs NAME, value")
            self.symbols[args[0]] = eval_expr(args[1], self.symbols, info)
        elif d == ".word":
            args = split_args(rest)
            self.items.append(dict(kind="word", sec=self.section, off=self.off[self.section],
                                   size=4 * len(args), args=args, info=info, raw=s))
            self.off[self.section] += 4 * len(args)
        elif d in (".asciz", ".ascii"):
            m = re.match(r'^"(.*)"$', rest.strip())
            if not m:
                raise AsmError(f"{d} needs a quoted string")
            txt = m.group(1).encode().decode("unicode_escape")
            data = txt.encode("latin-1") + (b"\x00" if d == ".asciz" else b"")
            pad = (-len(data)) % 4
            self.items.append(dict(kind="bytes", sec=self.section, off=self.off[self.section],
                                   size=len(data) + pad, data=data + b"\x00" * pad,
                                   info=info, raw=s))
            self.off[self.section] += len(data) + pad
        elif d == ".space":
            n = eval_expr(rest, self.symbols, info)
            self.items.append(dict(kind="space", sec=self.section, off=self.off[self.section],
                                   size=n, info=info, raw=s))
            self.off[self.section] += n
        elif d == ".align":
            n = eval_expr(rest, self.symbols, info)
            cur = self.off[self.section]
            pad = (-cur) % n
            if pad:
                self.items.append(dict(kind="space", sec=self.section, off=cur, size=pad,
                                       info=info, raw=s))
                self.off[self.section] += pad
        else:
            raise AsmError(f"unknown directive '{d}'")

    def instruction(self, s, info):
        parts = s.split(None, 1)
        mn = parts[0].lower()
        rest = parts[1] if len(parts) > 1 else ""
        args = split_args(rest)
        size, nwords = self.size_of(mn, args, info)
        self.items.append(dict(kind="insn", sec=self.section, off=self.off[self.section],
                               size=size, mn=mn, args=args, nwords=nwords,
                               info=info, raw=s))
        self.off[self.section] += size

    def size_of(self, mn, args, info):
        if mn == "li":
            v = try_eval(args[1], self.symbols, info) if len(args) == 2 else None
            if v is not None and -2048 <= v <= 2047:
                return 4, 1
            return 8, 2
        if mn in ("la", "call"):
            return 8, 2
        return 4, 1

    def encode_insn(self, mn, args, pc, info, nwords=1):
        E = lambda t: eval_expr(t, self.symbols, info)
        words = []

        def branch_off(target_expr):
            tgt = E(target_expr)
            off = tgt - pc
            imm_check_signed(off, 13, "branch offset", info)
            return off

        if mn in R_OPS:
            f7, f3 = R_OPS[mn]
            rd, rs1, rs2 = reg(args[0]), reg(args[1]), reg(args[2])
            words.append(enc_r(f7, rs2, rs1, f3, rd, OPC_OP))
        elif mn in I_OPS:
            f3, is_sh = I_OPS[mn]
            rd, rs1 = reg(args[0]), reg(args[1])
            imm = E(args[2])
            if is_sh:
                if not (0 <= imm <= 31):
                    raise AsmError(f"bad shift amount {args[2]}")
                if mn == "srai":
                    imm |= 0x400
            else:
                imm_check_signed(imm, 12, "immediate", info)
            words.append(enc_i(imm, rs1, f3, rd, OPC_OPIMM))
        elif mn == "lw":
            off, rs1 = parse_mem(args[1], self.symbols, info)
            imm_check_signed(off, 12, "offset", info)
            words.append(enc_i(off, rs1, 2, reg(args[0]), OPC_LOAD))
        elif mn == "sw":
            off, rs1 = parse_mem(args[1], self.symbols, info)
            imm_check_signed(off, 12, "offset", info)
            words.append(enc_s(off, reg(args[0]), rs1, 2, OPC_STORE))
        elif mn in B_OPS:
            off = branch_off(args[2])
            words.append(enc_b(off, reg(args[1]), reg(args[0]), B_OPS[mn], OPC_BRANCH))
        elif mn == "lui":
            words.append(enc_u(E(args[1]), reg(args[0]), OPC_LUI))
        elif mn == "auipc":
            words.append(enc_u(E(args[1]), reg(args[0]), OPC_AUIPC))
        elif mn == "jal":
            if len(args) == 1:
                rd, tgt = 1, args[0]
            else:
                rd, tgt = reg(args[0]), args[1]
            off = E(tgt) - pc
            imm_check_signed(off, 21, "jal offset", info)
            words.append(enc_j(off, rd, OPC_JAL))
        elif mn == "jalr":
            if len(args) == 2 and "(" in args[1]:
                off, rs1 = parse_mem(args[1], self.symbols, info)
                rd = reg(args[0])
            elif len(args) == 3:
                rd, rs1, off = reg(args[0]), reg(args[1]), E(args[2])
            elif len(args) == 1:
                rd, rs1, off = 0, reg(args[0]), 0
            else:
                raise AsmError("bad jalr operands")
            imm_check_signed(off, 12, "offset", info)
            words.append(enc_i(off, rs1, 0, rd, OPC_JALR))
        elif mn == "mret":
            words.append(enc_i(0x302, 0, 0, 0, OPC_SYSTEM))
        elif mn == "cdot":
            words.append(enc_r(0, 0, 0, 0, reg(args[0]), OPC_CUSTOM0))
        elif mn == "nop":
            words.append(enc_i(0, 0, 0, 0, OPC_OPIMM))
        elif mn == "mv":
            words.append(enc_i(0, reg(args[1]), 0, reg(args[0]), OPC_OPIMM))
        elif mn == "not":
            words.append(enc_i(-1, reg(args[1]), 4, reg(args[0]), OPC_OPIMM))
        elif mn == "neg":
            words.append(enc_r(0x20, reg(args[1]), 0, 0, reg(args[0]), OPC_OP))
        elif mn == "seqz":
            words.append(enc_i(1, reg(args[1]), 3, reg(args[0]), OPC_OPIMM))
        elif mn == "snez":
            words.append(enc_r(0, reg(args[1]), 0, 3, reg(args[0]), OPC_OP))
        elif mn == "li":
            rd = reg(args[0])
            v = E(args[1]) & 0xFFFFFFFF
            sv = v - (1 << 32) if v & 0x80000000 else v
            if -2048 <= sv <= 2047:
                words.append(enc_i(sv, 0, 0, rd, OPC_OPIMM))
            else:
                hi = ((v + 0x800) >> 12) & 0xFFFFF
                lo = sv - (((hi << 12) & 0xFFFFFFFF) - (1 << 32) if (hi << 12) & 0x80000000 else (hi << 12))
                lo = sv - (((hi << 12) if hi < 0x80000 else (hi << 12) - (1 << 32)))
                words.append(enc_u(hi, rd, OPC_LUI))
                words.append(enc_i(lo, rd, 0, rd, OPC_OPIMM))
        elif mn == "la":
            rd = reg(args[0])
            v = E(args[1]) & 0xFFFFFFFF
            hi = ((v + 0x800) >> 12) & 0xFFFFF
            lo = v & 0xFFF
            if lo >= 0x800:
                lo -= 0x1000
            words.append(enc_u(hi, rd, OPC_LUI))
            words.append(enc_i(lo, rd, 0, rd, OPC_OPIMM))
        elif mn == "call":
            v = E(args[0])
            hi = ((v + 0x800) >> 12) & 0xFFFFF
            lo = v & 0xFFF
            if lo >= 0x800:
                lo -= 0x1000
            words.append(enc_u(hi, 1, OPC_AUIPC))
            rel = v - pc
            hi = ((rel + 0x800) >> 12) & 0xFFFFF
            lo = rel - (((hi << 12) if hi < 0x80000 else (hi << 12) - (1 << 32)))
            words[0] = enc_u(hi, 1, OPC_AUIPC)
            words.append(enc_i(lo, 1, 0, 1, OPC_JALR))
        elif mn == "j":
            off = E(args[0]) - pc
            imm_check_signed(off, 21, "jump offset", info)
            words.append(enc_j(off, 0, OPC_JAL))
        elif mn == "jr":
            words.append(enc_i(0, reg(args[0]), 0, 0, OPC_JALR))
        elif mn == "ret":
            words.append(enc_i(0, 1, 0, 0, OPC_JALR))
        elif mn == "beqz":
            words.append(enc_b(branch_off(args[1]), 0, reg(args[0]), 0, OPC_BRANCH))
        elif mn == "bnez":
            words.append(enc_b(branch_off(args[1]), 0, reg(args[0]), 1, OPC_BRANCH))
        elif mn == "bltz":
            words.append(enc_b(branch_off(args[1]), 0, reg(args[0]), 4, OPC_BRANCH))
        elif mn == "bgez":
            words.append(enc_b(branch_off(args[1]), 0, reg(args[0]), 5, OPC_BRANCH))
        elif mn == "bgtz":
            words.append(enc_b(branch_off(args[1]), reg(args[0]), 0, 4, OPC_BRANCH))
        elif mn == "blez":
            words.append(enc_b(branch_off(args[1]), reg(args[0]), 0, 5, OPC_BRANCH))
        elif mn == "ble":
            words.append(enc_b(branch_off(args[2]), reg(args[0]), reg(args[1]), 5, OPC_BRANCH))
        elif mn == "bgt":
            words.append(enc_b(branch_off(args[2]), reg(args[0]), reg(args[1]), 4, OPC_BRANCH))
        elif mn == "bleu":
            words.append(enc_b(branch_off(args[2]), reg(args[0]), reg(args[1]), 7, OPC_BRANCH))
        elif mn == "bgtu":
            words.append(enc_b(branch_off(args[2]), reg(args[0]), reg(args[1]), 6, OPC_BRANCH))
        else:
            raise AsmError(f"unknown instruction '{mn}'")
        return words

    def encode_word(self, args, info):
        return [eval_expr(a, self.symbols, info) & 0xFFFFFFFF for a in args]

    def run_pass2(self):
        images = {"text": {}, "data": {}}
        listing = []
        for it in self.items:
            info = it["info"]
            try:
                if it["kind"] == "insn":
                    words = self.encode_insn(it["mn"], it["args"], TEXT_BASE + it["off"],
                                             info, it["nwords"])
                    if 4 * len(words) != it["size"]:
                        raise AsmError(f"internal: size mismatch for '{it['raw']}'")
                elif it["kind"] == "word":
                    words = self.encode_word(it["args"], info)
                elif it["kind"] == "bytes":
                    b = it["data"]
                    words = [int.from_bytes(b[i:i + 4], "little") for i in range(0, len(b), 4)]
                elif it["kind"] == "space":
                    words = [0] * (it["size"] // 4)
                else:
                    words = []
                for i, w in enumerate(words):
                    images[it["sec"]][it["off"] // 4 + i] = w & 0xFFFFFFFF
                listing.append((it, words))
            except AsmError as e:
                die(str(e), *info)
        return images, listing


def write_hex(path, image):
    top = max(image.keys()) + 1 if image else 0
    with open(path, "w") as f:
        for i in range(top):
            f.write(f"{image.get(i, 0):08x}\n")


def write_lst(path, listing, symbols):
    with open(path, "w") as f:
        f.write("; listing\n; symbols:\n")
        for k in sorted(symbols, key=lambda s: symbols[s]):
            f.write(f";   {k:24s} = 0x{symbols[k]:08x}\n")
        f.write(";\n")
        for it, words in listing:
            base = TEXT_BASE if it["sec"] == "text" else DATA_BASE
            addr = base + it["off"]
            wtxt = "  ".join(f"{w:08x}" for w in words)
            f.write(f"{addr:08x}  {wtxt:36s}  {it['raw']}\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input")
    ap.add_argument("-o", "--out", required=True, help="output prefix (writes PREFIX_prog.hex and PREFIX_data.hex)")
    ap.add_argument("--list", dest="lst", help="write listing file")
    args = ap.parse_args()

    asm = Assembler()
    with open(args.input) as f:
        lines = f.readlines()
    for n, raw in enumerate(lines, 1):
        try:
            asm.feed(raw, args.input, n)
        except AsmError as e:
            die(str(e), args.input, n)

    images, listing = asm.run_pass2()
    write_hex(args.out + "_prog.hex", images["text"])
    write_hex(args.out + "_data.hex", images["data"])
    if args.lst:
        write_lst(args.lst, listing, asm.symbols)
    n_text = max(images["text"].keys()) + 1 if images["text"] else 0
    n_data = max(images["data"].keys()) + 1 if images["data"] else 0
    sys.stderr.write(f"asm: {args.input}: {n_text} instr words, {n_data} data words\n")


if __name__ == "__main__":
    main()
