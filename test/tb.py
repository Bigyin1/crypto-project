import hashlib

import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock
from cocotb.types import LogicArray, Range


def prep_data(raw_data: str) -> LogicArray:
    logic = LogicArray(
        int(raw_data.encode().hex(), 16), range=Range(511, 0)
    )

    bitlen = len(raw_data) * 8
    assert (bitlen < 256)

    logic[bitlen] = 1

    k_zero = 448 - bitlen - 1
    logic[bitlen + 1 + k_zero - 1:bitlen + 1] = 0

    len_start_idx = bitlen + 1 + k_zero
    logic[len_start_idx + 7:len_start_idx] = bitlen

    print(logic)
    return logic


async def reset_dut(clk, rstn):
    rstn.value = 0
    await RisingEdge(clk)

    rstn.value = 1
    await RisingEdge(clk)


@cocotb.test()
async def tb_sha256(dut):

    data = "Hello, World"

    input_clock = Clock(dut.clk_i, 10, unit="ps")
    input_clock.start()

    await reset_dut(dut.clk_i, dut.rstn_i)

    dut.message_blk_vld_i.value = 1
    dut.message_blk_i.value = prep_data(data)
    await RisingEdge(dut.clk_i)
    dut.message_blk_vld_i.value = 0

    await RisingEdge(dut.hash_vld_o)

    print("Ours", hex(dut.hash_o.value)[2:])

    print(
        "Real", hashlib.sha256(data.encode()).hexdigest()
    )
