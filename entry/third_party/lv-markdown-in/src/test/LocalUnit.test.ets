import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { parseMarkdown } from '../main/ets/enhance/utils/ast';

function parse(markdown: string): ESObject[] {
  return parseMarkdown(markdown, [], {}) as ESObject[];
}

function childrenOf(node: ESObject): ESObject[] {
  return (node.children ?? []) as ESObject[];
}

function expectNodeType(node: ESObject, type: string): void {
  expect(node.type).assertEqual(type);
}

export default function localUnitTest() {
  describe('localUnitTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    });
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    });
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    });
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    });
    it('keeps block latex inside ordered list item', 0, () => {
      const tree = parse([
        '1. alpha',
        '   $$',
        '   x_n = n',
        '   $$',
        '2. beta'
      ].join('\n'));

      expect(tree.length).assertEqual(1);
      const list = tree[0];
      expectNodeType(list, 'ol');
      expect(childrenOf(list).length).assertEqual(2);

      const firstItem = childrenOf(list)[0];
      expect(childrenOf(firstItem).length).assertEqual(2);
      const latexParagraph = childrenOf(firstItem)[1];
      expectNodeType(latexParagraph, 'paragraph');

      const latexNode = childrenOf(latexParagraph)[0];
      expectNodeType(latexNode, 'latex');
      expect(latexNode.block).assertEqual(true);
      expect(latexNode.text).assertEqual('x_n = n');
    });

    it('keeps ordered list numbering after nested list and block latex', 0, () => {
      const tree = parse([
        '1. first',
        '2. second',
        '   - nested',
        '   $$',
        '   I = \\int_0^1 x dx',
        '   $$',
        '3. third'
      ].join('\n'));

      expect(tree.length).assertEqual(1);
      const list = tree[0];
      expectNodeType(list, 'ol');
      expect(childrenOf(list).length).assertEqual(3);

      const secondItem = childrenOf(list)[1];
      expect(childrenOf(secondItem).length).assertEqual(3);
      expectNodeType(childrenOf(secondItem)[1], 'ul');

      const latexParagraph = childrenOf(secondItem)[2];
      expectNodeType(latexParagraph, 'paragraph');
      const latexNode = childrenOf(latexParagraph)[0];
      expectNodeType(latexNode, 'latex');
      expect(latexNode.block).assertEqual(true);
      expect(latexNode.text).assertEqual('I = \\int_0^1 x dx');
    });

    it('keeps table continuation inside list item', 0, () => {
      const tree = parse([
        '- item',
        '  | A | B |',
        '  | - | - |',
        '  | 1 | 2 |',
        '- next'
      ].join('\n'));

      expect(tree.length).assertEqual(1);
      const list = tree[0];
      expectNodeType(list, 'ul');
      expect(childrenOf(list).length).assertEqual(2);

      const firstItem = childrenOf(list)[0];
      expect(childrenOf(firstItem).length).assertEqual(2);
      const table = childrenOf(firstItem)[1];
      expectNodeType(table, 'table');
      expect((table.header as ESObject[]).length).assertEqual(2);
      expect((table.rows as ESObject[]).length).assertEqual(1);
    });

    it('keeps ordinary nested list structure', 0, () => {
      const tree = parse([
        '- parent',
        '  - child',
        '- next'
      ].join('\n'));

      expect(tree.length).assertEqual(1);
      const list = tree[0];
      expectNodeType(list, 'ul');
      expect(childrenOf(list).length).assertEqual(2);

      const parentItem = childrenOf(list)[0];
      expect(childrenOf(parentItem).length).assertEqual(2);
      const nestedList = childrenOf(parentItem)[1];
      expectNodeType(nestedList, 'ul');
      expect(childrenOf(nestedList).length).assertEqual(1);
    });

    it('keeps inline latex as inline node in list item', 0, () => {
      const tree = parse([
        '- inline $x_n$ value',
        '- next'
      ].join('\n'));

      const list = tree[0];
      const firstParagraph = childrenOf(childrenOf(list)[0])[0];
      const inlineNodes = childrenOf(firstParagraph);
      expectNodeType(inlineNodes[1], 'latex');
      expect(inlineNodes[1].block).assertEqual(false);
      expect(inlineNodes[1].text).assertEqual('x_n');
    });
  });
}
