import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock


async def reset_dut(clk, rstn):
    rstn.value = 0
    await RisingEdge(clk)

    rstn.value = 1
    await RisingEdge(clk)


@cocotb.test()
async def tb_sha256(dut):

    input_clock = Clock(dut.clk_i, 10, unit="ps")
    input_clock.start()

    await reset_dut(dut.clk_i, dut.rstn_i)

    dut.message_blk_vld_i.value = 1
    dut.message_blk_i.value = 0xBEEF
    await RisingEdge(dut.clk_i)
    dut.message_blk_vld_i.value = 0

    await RisingEdge(dut.hash_vld_o)

    print(dut.hash_o.value)
