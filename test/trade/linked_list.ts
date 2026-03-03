import { LinkedListTest } from "../../typechain";

import { expect } from "chai";

import { checkTradeBook } from "./helpers/helpers";
import { LinkedListTestFactory } from "./factories/linked-list-test.factory";

describe("LinkedListTest Contract", function () {
    let tradeBook: LinkedListTest;

    // Helper function to convert uint to bytes16 for testing
    function toBytes16(num: number): string {
        return "0x" + num.toString(16).padStart(32, "0");
    }

    beforeEach(async function () {
        tradeBook = await LinkedListTestFactory.create();
    });

    describe("Creation", function () {
        it("should start with an empty order book", async function () {
            await checkTradeBook(tradeBook, []);
        });
        it("should not exist a list", async function () {
            expect(await tradeBook.listExists()).to.be.eq(false);
        });
    });

    describe("testPushHead", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));
        });

        it("should be able to push one order", async function () {
            await tradeBook.testPushHead(1);
            await checkTradeBook(tradeBook, [1]);
        });
        it("should be able to push two orders", async function () {
            await tradeBook.testPushHead(1);
            await tradeBook.testPushHead(2);
            await checkTradeBook(tradeBook, [2, 1]); // head -> tail
        });
        it("should be able to push three orders", async function () {
            await tradeBook.testPushHead(1);
            await tradeBook.testPushHead(2);
            await tradeBook.testPushHead(3);
            await checkTradeBook(tradeBook, [3, 2, 1]); // head -> tail
        });
    });

    describe("testPushHeadBytes", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));
        });

        it("should be able to push one order", async function () {
            await tradeBook.testPushHeadBytes(toBytes16(1));
            await checkTradeBook(tradeBook, [1]);
        });
        it("should be able to push two orders", async function () {
            await tradeBook.testPushHeadBytes(toBytes16(1));
            await tradeBook.testPushHeadBytes(toBytes16(2));
            await checkTradeBook(tradeBook, [2, 1]); // head -> tail
        });
        it("should be able to push three orders", async function () {
            await tradeBook.testPushHeadBytes(toBytes16(1));
            await tradeBook.testPushHeadBytes(toBytes16(2));
            await tradeBook.testPushHeadBytes(toBytes16(3));
            await checkTradeBook(tradeBook, [3, 2, 1]); // head -> tail
        });
    });

    describe("testPushTail", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));
        });

        it("should be able to push one order", async function () {
            await tradeBook.testPushTail(1);
            await checkTradeBook(tradeBook, [1]);
        });
        it("should be able to push two orders", async function () {
            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await checkTradeBook(tradeBook, [1, 2]); // head -> tail
        });
        it("should be able to push three orders", async function () {
            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3);
            await checkTradeBook(tradeBook, [1, 2, 3]); // head -> tail
        });
    });

    describe("testPushTailBytes", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));
        });

        it("should be able to push one order", async function () {
            await tradeBook.testPushTailBytes(toBytes16(1));
            await checkTradeBook(tradeBook, [1]);
        });
        it("should be able to push two orders", async function () {
            await tradeBook.testPushTailBytes(toBytes16(1));
            await tradeBook.testPushTailBytes(toBytes16(2));
            await checkTradeBook(tradeBook, [1, 2]); // head -> tail
        });
        it("should be able to push three orders", async function () {
            await tradeBook.testPushTailBytes(toBytes16(1));
            await tradeBook.testPushTailBytes(toBytes16(2));
            await tradeBook.testPushTailBytes(toBytes16(3));
            await checkTradeBook(tradeBook, [1, 2, 3]); // head -> tail
        });
    });

    describe("testInsertAfter", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));
            await tradeBook.testRegisterTrade(10, toBytes16(10));

            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3);
        });

        it("should be able to insert after sentinel", async function () {
            await tradeBook.testInsertAfter(0, 10); // inserting after 0 (sentinel)
            await checkTradeBook(tradeBook, [10, 1, 2, 3]); // head -> tail
        });
        it("should be able to insert after specific position", async function () {
            await tradeBook.testInsertAfter(2, 10); // inserting after 2
            await checkTradeBook(tradeBook, [1, 2, 10, 3]); // head -> tail
        });
    });

    describe("testInsertAfterBytes", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));
            await tradeBook.testRegisterTrade(10, toBytes16(10));

            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3);
        });

        it("should be able to insert after sentinel", async function () {
            await tradeBook.testInsertAfterBytes(toBytes16(0), toBytes16(10)); // inserting after 0 (sentinel)
            await checkTradeBook(tradeBook, [10, 1, 2, 3]); // head -> tail
        });
        it("should be able to insert after specific position", async function () {
            await tradeBook.testInsertAfterBytes(toBytes16(2), toBytes16(10)); // inserting after 2
            await checkTradeBook(tradeBook, [1, 2, 10, 3]); // head -> tail
        });
    });

    describe("testInsertBefore", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));
            await tradeBook.testRegisterTrade(10, toBytes16(10));

            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3);
        });

        it("should be able to insert before sentinel", async function () {
            await tradeBook.testInsertBefore(0, 10); // inserting before 0 (sentinel) - same as push head
            await checkTradeBook(tradeBook, [1, 2, 3, 10]); // head -> tail
        });
        it("should be able to insert before specific position", async function () {
            await tradeBook.testInsertBefore(2, 10); // inserting before 2
            await checkTradeBook(tradeBook, [1, 10, 2, 3]); // head -> tail
        });
    });

    describe("testInsertBeforeBytes", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));
            await tradeBook.testRegisterTrade(10, toBytes16(10));

            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3);
        });

        it("should be able to insert before sentinel", async function () {
            await tradeBook.testInsertBeforeBytes(toBytes16(0), toBytes16(10)); // inserting before 0 (sentinel)
            await checkTradeBook(tradeBook, [1, 2, 3, 10]); // head -> tail
        });
        it("should be able to insert before specific position", async function () {
            await tradeBook.testInsertBeforeBytes(toBytes16(2), toBytes16(10)); // inserting before 2
            await checkTradeBook(tradeBook, [1, 10, 2, 3]); // head -> tail
        });
    });

    describe("testPopHead", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));

            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3);
        });

        it("should be able to pop head once", async function () {
            await tradeBook.testPopHead();
            await checkTradeBook(tradeBook, [2, 3]); // head -> tail
        });
        it("should be able to pop head twice", async function () {
            await tradeBook.testPopHead();
            await tradeBook.testPopHead();
            await checkTradeBook(tradeBook, [3]); // head -> tail
        });
        it("should be able to pop head three times", async function () {
            await tradeBook.testPopHead();
            await tradeBook.testPopHead();
            await tradeBook.testPopHead();
            await checkTradeBook(tradeBook, []); // head -> tail
        });
    });

    describe("testPopHeadBytes", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));

            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3);
        });

        it("should be able to pop head once", async function () {
            await tradeBook.testPopHeadBytes();
            await checkTradeBook(tradeBook, [2, 3]); // head -> tail
        });
        it("should be able to pop head twice", async function () {
            await tradeBook.testPopHeadBytes();
            await tradeBook.testPopHeadBytes();
            await checkTradeBook(tradeBook, [3]); // head -> tail
        });
        it("should be able to pop head three times", async function () {
            await tradeBook.testPopHeadBytes();
            await tradeBook.testPopHeadBytes();
            await tradeBook.testPopHeadBytes();
            await checkTradeBook(tradeBook, []); // head -> tail
        });
    });

    describe("testPopTail", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));

            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3);
        });

        it("should be able to pop tail once", async function () {
            await tradeBook.testPopTail();
            await checkTradeBook(tradeBook, [1, 2]); // head -> tail
        });
        it("should be able to pop tail twice", async function () {
            await tradeBook.testPopTail();
            await tradeBook.testPopTail();
            await checkTradeBook(tradeBook, [1]); // head -> tail
        });
        it("should be able to pop tail three times", async function () {
            await tradeBook.testPopTail();
            await tradeBook.testPopTail();
            await tradeBook.testPopTail();
            await checkTradeBook(tradeBook, []); // head -> tail
        });
    });

    describe("testPopTailBytes", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));

            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3);
        });

        it("should be able to pop tail once", async function () {
            await tradeBook.testPopTailBytes();
            await checkTradeBook(tradeBook, [1, 2]); // head -> tail
        });
        it("should be able to pop tail twice", async function () {
            await tradeBook.testPopTailBytes();
            await tradeBook.testPopTailBytes();
            await checkTradeBook(tradeBook, [1]); // head -> tail
        });
        it("should be able to pop tail three times", async function () {
            await tradeBook.testPopTailBytes();
            await tradeBook.testPopTailBytes();
            await tradeBook.testPopTailBytes();
            await checkTradeBook(tradeBook, []); // head -> tail
        });
    });

    describe("testRemove", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));

            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3); // [1,2,3]
        });

        it("should be able to testRemove once", async function () {
            await tradeBook.testRemove(2);
            await checkTradeBook(tradeBook, [1, 3]); // head -> tail
        });
        it("should be able to testRemove twice", async function () {
            await tradeBook.testRemove(2);
            await tradeBook.testRemove(3);
            await checkTradeBook(tradeBook, [1]); // head -> tail
        });
        it("should be able to testRemove three times", async function () {
            await tradeBook.testRemove(2);
            await tradeBook.testRemove(3);
            await tradeBook.testRemove(1);
            await checkTradeBook(tradeBook, []); // head -> tail
        });
    });

    describe("testRemoveBytes", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));

            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3); // [1,2,3]
        });

        it("should be able to testRemove once", async function () {
            await tradeBook.testRemoveBytes(toBytes16(2));
            await checkTradeBook(tradeBook, [1, 3]); // head -> tail
        });
        it("should be able to testRemove twice", async function () {
            await tradeBook.testRemoveBytes(toBytes16(2));
            await tradeBook.testRemoveBytes(toBytes16(3));
            await checkTradeBook(tradeBook, [1]); // head -> tail
        });
        it("should be able to testRemove three times", async function () {
            await tradeBook.testRemoveBytes(toBytes16(1));
            await tradeBook.testRemoveBytes(toBytes16(2));
            await tradeBook.testRemoveBytes(toBytes16(3));
            await checkTradeBook(tradeBook, []); // head -> tail
        });
    });

    describe("testMove", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));

            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3); // [1,2,3]
        });

        it("should be able to testMove forward", async function () {
            await tradeBook.testMove(2, 1, false); // testMove 2 into position 1, and do it before it
            await checkTradeBook(tradeBook, [2, 1, 3]); // head -> tail
        });
        it("should be able to testMove backward", async function () {
            await tradeBook.testMove(1, 3, true); // testMove 1 into position 3, and do it after it
            await checkTradeBook(tradeBook, [2, 3, 1]); // head -> tail
        });
    });

    describe("testMoveBytes", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));

            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3); // [1,2,3]
        });

        it("should be able to testMove forward", async function () {
            await tradeBook.testMoveBytes(toBytes16(2), toBytes16(1), false);
            await checkTradeBook(tradeBook, [2, 1, 3]); // head -> tail
        });
        it("should be able to testMove backward", async function () {
            await tradeBook.testMoveBytes(toBytes16(1), toBytes16(3), true);
            await checkTradeBook(tradeBook, [2, 3, 1]); // head -> tail
        });
    });

    describe("getAdjacent", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));

            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3); // [1,2,3]
        });

        it("should be able to get adjacent order forward", async function () {
            const [exists, order] = await tradeBook.getAdjacent(2, true);
            expect(exists).to.be.eq(true);
            expect(order).to.be.eq(3);
        });
        it("should be able to get adjacent order backwards", async function () {
            const [exists, order] = await tradeBook.getAdjacent(2, false);
            expect(exists).to.be.eq(true);
            expect(order).to.be.eq(1);
        });
        it("should return sentinel if last order and forward", async function () {
            const [exists, order] = await tradeBook.getAdjacent(3, true);
            expect(exists).to.be.eq(true); // this refers to whether the order we submitted exists
            expect(order).to.be.eq(0); // next is sentinel
        });
        it("should return sentinel if first order and previous", async function () {
            const [exists, order] = await tradeBook.getAdjacent(1, false);
            expect(exists).to.be.eq(true); // this refers to whether the order we submitted exists
            expect(order).to.be.eq(0); // next is sentinel
        });
    });

    describe("getAdjacentBytes", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));

            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3); // [1,2,3]
        });

        it("should be able to get adjacent order forward", async function () {
            const [exists, order] = await tradeBook.getAdjacentBytes(
                toBytes16(2),
                true
            );
            expect(exists).to.be.eq(true);
            expect(order).to.equal(toBytes16(3));
        });
        it("should be able to get adjacent order backwards", async function () {
            const [exists, order] = await tradeBook.getAdjacentBytes(
                toBytes16(2),
                false
            );
            expect(exists).to.be.eq(true);
            expect(order).to.equal(toBytes16(1));
        });
        it("should return sentinel if last order and forward", async function () {
            const [exists, order] = await tradeBook.getAdjacentBytes(
                toBytes16(3),
                true
            );
            expect(exists).to.be.eq(true); // this refers to whether the order we submitted exists
            expect(order).to.equal(toBytes16(0)); // next is sentinel
        });
        it("should return sentinel if first order and previous", async function () {
            const [exists, order] = await tradeBook.getAdjacentBytes(
                toBytes16(1),
                false
            );
            expect(exists).to.be.eq(true); // this refers to whether the order we submitted exists
            expect(order).to.equal(toBytes16(0)); // next is sentinel
        });
    });

    describe("getNext", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));

            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3); // [1,2,3]
        });

        it("should be able to get next order", async function () {
            const [exists, order] = await tradeBook.getNext(2);
            expect(exists).to.be.eq(true);
            expect(order).to.be.eq(3);
        });
        it("should return sentinel if last order", async function () {
            const [exists, order] = await tradeBook.getNext(3);
            expect(exists).to.be.eq(true); // this refers to whether the order we submitted exists
            expect(order).to.be.eq(0); // next is sentinel
        });
        it("should return first order if sentinel", async function () {
            const [exists, order] = await tradeBook.getNext(0);
            expect(exists).to.be.eq(true); // this refers to whether the order we submitted exists
            expect(order).to.be.eq(1); // next is sentinel
        });
    });

    describe("getNextBytes", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));

            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3); // [1,2,3]
        });

        it("should be able to get next order", async function () {
            const [exists, order] = await tradeBook.getNextBytes(toBytes16(2));
            expect(exists).to.be.eq(true);
            expect(order).to.equal(toBytes16(3));
        });
        it("should return sentinel if last order", async function () {
            const [exists, order] = await tradeBook.getNextBytes(toBytes16(3));
            expect(exists).to.be.eq(true); // this refers to whether the order we submitted exists
            expect(order).to.equal(toBytes16(0)); // next is sentinel
        });
        it("should return first order if sentinel", async function () {
            const [exists, order] = await tradeBook.getNextBytes(toBytes16(0));
            expect(exists).to.be.eq(true); // this refers to whether the order we submitted exists
            expect(order).to.equal(toBytes16(1)); // next is sentinel
        });
    });

    describe("getPrev", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));

            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3); // [1,2,3]
        });

        it("should be able to get prev order", async function () {
            const [exists, order] = await tradeBook.getPrev(2);
            expect(exists).to.be.eq(true);
            expect(order).to.be.eq(1);
        });
        it("should return sentinel if first order", async function () {
            const [exists, order] = await tradeBook.getPrev(1);
            expect(exists).to.be.eq(true); // this refers to whether the order we submitted exists
            expect(order).to.be.eq(0); // next is sentinel
        });
        it("should return last order if sentinel", async function () {
            const [exists, order] = await tradeBook.getPrev(0);
            expect(exists).to.be.eq(true); // this refers to whether the order we submitted exists
            expect(order).to.be.eq(3); //
        });
    });

    describe("getPrevBytes", function () {
        beforeEach(async function () {
            await tradeBook.testRegisterTrade(1, toBytes16(1));
            await tradeBook.testRegisterTrade(2, toBytes16(2));
            await tradeBook.testRegisterTrade(3, toBytes16(3));

            await tradeBook.testPushTail(1);
            await tradeBook.testPushTail(2);
            await tradeBook.testPushTail(3); // [1,2,3]
        });

        it("should be able to get prev order", async function () {
            const [exists, order] = await tradeBook.getPrevBytes(toBytes16(2));
            expect(exists).to.be.eq(true);
            expect(order).to.equal(toBytes16(1));
        });
        it("should return sentinel if first order", async function () {
            const [exists, order] = await tradeBook.getPrevBytes(toBytes16(1));
            expect(exists).to.be.eq(true); // this refers to whether the order we submitted exists
            expect(order).to.equal(toBytes16(0)); // next is sentinel
        });
        it("should return last order if sentinel", async function () {
            const [exists, order] = await tradeBook.getPrevBytes(toBytes16(0));
            expect(exists).to.be.eq(true); // this refers to whether the order we submitted exists
            expect(order).to.equal(toBytes16(3)); //
        });
    });
});
