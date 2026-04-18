/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

import {
  commitMessageFieldsToString,
  detectSchemaForMessage,
  isFieldNonEmpty,
  mergeCommitMessageFields,
  mergeManyCommitMessageFields,
  parseCommitMessageFields,
} from '../CommitMessageFields';
import {OSSCommitMessageFieldSchema} from '../OSSCommitMessageFieldsSchema';

describe('isFieldNonEmpty', () => {
  it('handles strings', () => {
    expect(isFieldNonEmpty('foo')).toBeTruthy();
    expect(isFieldNonEmpty('')).toBeFalsy();
  });
  it('handles arrays', () => {
    expect(isFieldNonEmpty(['foo'])).toBeTruthy();
    expect(isFieldNonEmpty([])).toBeFalsy();
    expect(isFieldNonEmpty([''])).toBeFalsy();
  });
});

describe('InternalCommitInfoFields', () => {
  it('parses messages correctly', () => {
    const parsed = parseCommitMessageFields(
      OSSCommitMessageFieldSchema,
      'my title',
      `My description!
another line
`,
    );

    expect(parsed.Title).toEqual('my title');
    expect(parsed.Description).toEqual('My description!\nanother line\n');
  });

  it('converts to string properly', () => {
    expect(
      commitMessageFieldsToString(OSSCommitMessageFieldSchema, {
        Title: 'my title',
        Description: 'my summary\nline 2',
      }),
    ).toEqual(
      `my title

my summary
line 2`,
    );
  });

  it('handles empty title when converting to string', () => {
    expect(
      commitMessageFieldsToString(OSSCommitMessageFieldSchema, {
        Title: '',
        Description: 'my summary\nline 2',
      }),
    ).toEqual(expect.stringMatching(/Temporary Commit at .*\n\nmy summary\nline 2/));
  });

  it('leading spaces in title is OK', () => {
    expect(
      commitMessageFieldsToString(OSSCommitMessageFieldSchema, {
        Title: '     title',
        Description: 'my summary\nline 2',
      }),
    ).toEqual(
      `     title

my summary
line 2`,
    );
  });

  describe('mergeCommitMessageFields', () => {
    it('can merge fields', () => {
      expect(
        mergeCommitMessageFields(
          OSSCommitMessageFieldSchema,
          {
            Title: 'Commit A',
            Description: 'Description A',
          },
          {
            Title: 'Commit B',
            Description: 'Description B',
          },
        ),
      ).toEqual({
        Title: 'Commit A, Commit B',
        Description: 'Description A\nDescription B',
      });
    });

    it('leaves identical fields alone', () => {
      expect(
        mergeCommitMessageFields(
          OSSCommitMessageFieldSchema,
          {
            Title: 'Commit A',
            Description: 'Description A',
          },
          {
            Title: 'Commit A',
            Description: 'Description A',
          },
        ),
      ).toEqual({
        Title: 'Commit A',
        Description: 'Description A',
      });
    });

    it('ignores empty fields', () => {
      expect(
        mergeCommitMessageFields(
          OSSCommitMessageFieldSchema,
          {
            Title: 'Commit A',
          },
          {
            Title: 'Commit B',
          },
        ),
      ).toEqual({
        Title: 'Commit A, Commit B',
      });
    });
  });

  describe('mergeManyCommitMessageFields', () => {
    it('can merge fields', () => {
      expect(
        mergeManyCommitMessageFields(OSSCommitMessageFieldSchema, [
          {
            Title: 'Commit A',
            Description: 'Description A',
          },
          {
            Title: 'Commit B',
            Description: 'Description B',
          },
          {
            Title: 'Commit C',
            Description: 'Description C',
          },
        ]),
      ).toEqual({
        Title: 'Commit A, Commit B, Commit C',
        Description: 'Description A\nDescription B\nDescription C',
      });
    });

    it('ignores empty fields', () => {
      expect(
        mergeManyCommitMessageFields(OSSCommitMessageFieldSchema, [
          {
            Title: 'Commit A',
          },
          {
            Title: 'Commit B',
          },
          {
            Title: 'Commit C',
          },
        ]),
      ).toEqual({
        Title: 'Commit A, Commit B, Commit C',
      });
    });
  });
});

// A mock structured schema similar to the internal Phabricator schema,
// used to test auto-detection logic without depending on internal imports.
const MockStructuredSchema = [
  {key: 'Title', type: 'title' as const, icon: 'milestone'},
  {key: 'Summary', type: 'textarea' as const, icon: 'note'},
  {key: 'Test Plan', type: 'textarea' as const, icon: 'checklist'},
  {key: 'Reviewers', type: 'field' as const, icon: 'account', typeaheadKind: 'meta-user' as const},
];

describe('detectSchemaForMessage', () => {
  it('returns OSS schema for plain git-style messages', () => {
    const result = detectSchemaForMessage(
      MockStructuredSchema,
      'This fixes issue #123\nanother line of description',
    );
    expect(result).toBe(OSSCommitMessageFieldSchema);
  });

  it('returns structured schema when Summary: marker is present', () => {
    const result = detectSchemaForMessage(
      MockStructuredSchema,
      '\nSummary: my summary\n\nTest Plan: my test plan',
    );
    expect(result).toBe(MockStructuredSchema);
  });

  it('returns structured schema when Test Plan: marker is present', () => {
    const result = detectSchemaForMessage(MockStructuredSchema, '\nTest Plan: run tests');
    expect(result).toBe(MockStructuredSchema);
  });

  it('returns structured schema for empty description', () => {
    const result = detectSchemaForMessage(MockStructuredSchema, '');
    expect(result).toBe(MockStructuredSchema);
  });

  it('returns structured schema for whitespace-only description', () => {
    const result = detectSchemaForMessage(MockStructuredSchema, '   \n  ');
    expect(result).toBe(MockStructuredSchema);
  });

  it('returns structured schema for undefined description (title-only commit)', () => {
    // Simulates a commit that has only a title and no description field.
    // At runtime, description may be undefined even though the type signature says string.
    const result = detectSchemaForMessage(MockStructuredSchema, undefined as unknown as string);
    expect(result).toBe(MockStructuredSchema);
  });

  it('returns OSS schema as-is if already using OSS schema', () => {
    const result = detectSchemaForMessage(OSSCommitMessageFieldSchema, 'any description here');
    expect(result).toBe(OSSCommitMessageFieldSchema);
  });

  it('round-trips plain message without injecting markers', () => {
    const description = 'This fixes issue #123\nanother line';
    const schema = detectSchemaForMessage(MockStructuredSchema, description);
    expect(schema).toBe(OSSCommitMessageFieldSchema);

    const parsed = parseCommitMessageFields(schema, 'Fix the bug', description);
    expect(parsed.Title).toEqual('Fix the bug');
    expect(parsed.Description).toEqual(description);

    const serialized = commitMessageFieldsToString(schema, parsed);
    expect(serialized).toEqual('Fix the bug\n\nThis fixes issue #123\nanother line');
    // No "Summary:" or "Test Plan:" injected
    expect(serialized).not.toContain('Summary:');
    expect(serialized).not.toContain('Test Plan:');
  });

  it('round-trips structured message preserving markers', () => {
    const description = '\nSummary: my summary\n\nTest Plan: run unit tests\n\nReviewers: alice';
    const schema = detectSchemaForMessage(MockStructuredSchema, description);
    expect(schema).toBe(MockStructuredSchema);

    const parsed = parseCommitMessageFields(schema, 'Add feature', description);
    expect(parsed.Title).toEqual('Add feature');
    expect(parsed.Summary).toEqual('my summary');
    expect(parsed['Test Plan']).toEqual('run unit tests');

    const serialized = commitMessageFieldsToString(schema, parsed);
    expect(serialized).toContain('Summary:');
    expect(serialized).toContain('Test Plan:');
  });
});
