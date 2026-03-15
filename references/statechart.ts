/**
 * OpenPredicaTree — Node State Machine (XState v5)
 *
 * DOCUMENTATION ONLY — not runtime code. Formalizes the statechart for the
 * OpenPredicaTree state machine. Complies with XState v5 type signature
 * but is not imported anywhere.
 *
 * Models the lifecycle of a single predicate node in the tree.
 * The tree is a forest of these machines coordinated by the root
 * active_node pointer in root.md.
 *
 * Node types:
 *   - branch (composite) — satisfied when all children are satisfied
 *   - leaf (executable) — satisfied when PRD is delivered via sprint
 *
 * Artifact chain:
 *   predicate.md → discovery.md → [prd.md → plan.md → results.md → review.md]
 *
 * Human gates (HITL):
 *   - Discovery result: human validates branch/leaf classification
 *   - PRD: human validates acceptance criteria before sprint
 *   - Subdivision: human validates proposed children
 *   - Result: human validates predicate was actually satisfied
 *   - Prune: human confirms unachievable assessment
 */

import { assign, createMachine } from "xstate";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type NodeType = "branch" | "leaf" | null;
type NodeStatus = "pending" | "satisfied" | "pruned" | "candidate";
type Confidence = "high" | "medium" | "low";

interface NodeContext {
  nodePath: string;
  treePath: string;
  repoRoot: string;
  predicate: string;
  depth: number;
  nodeType: NodeType;
  confidence: Confidence | null;
  prdSeed: string | null;
  proposedChildren: string[];
  reasoning: string | null;
  childCount: number;
  childrenSatisfied: number;
  childrenPruned: number;
  learnings: string | null;
  lastError: string | null;
}

type NodeEvent =
  // --- Discovery ---
  | { type: "DISCOVER" }
  | {
      type: "DISCOVERY_COMPLETE";
      achievable: boolean;
      nodeType: NodeType;
      confidence: Confidence;
      reasoning: string;
      proposedChildren: string[];
      prdSeed: string;
    }
  | { type: "DISCOVERY_ERROR"; message: string }

  // --- Human gates ---
  | { type: "CLASSIFY_BRANCH" }
  | { type: "CLASSIFY_LEAF" }
  | { type: "PRD_ACCEPTED" }
  | { type: "PRD_REJECTED"; feedback: string }
  | { type: "DECOMPOSITION_ACCEPTED" }
  | { type: "DECOMPOSITION_REJECTED"; correction?: string }
  | { type: "APPROVE" }
  | { type: "REJECT"; feedback: string }
  | { type: "PRUNE_CONFIRMED" }
  | { type: "PRUNE_DENIED"; additionalContext: string }

  // --- Sprint cycle ---
  | { type: "SPECIFY" }
  | { type: "PRD_READY" }
  | { type: "PLAN" }
  | { type: "PLAN_DONE" }
  | { type: "DELIVER" }
  | { type: "DELIVER_DONE" }
  | { type: "REVIEW" }
  | { type: "REVIEW_DONE" }
  | { type: "SHIP" }
  | { type: "SHIP_DONE" }

  // --- Branch ---
  | { type: "SUBDIVIDE" }
  | { type: "CHILDREN_SATISFIED" }

  // --- Terminal ---
  | { type: "ASCEND" };

// ---------------------------------------------------------------------------
// Machine definition
// ---------------------------------------------------------------------------

export const openPredicaTreeNode = createMachine(
  {
    id: "openPredicaTreeNode",
    types: {} as {
      context: NodeContext;
      events: NodeEvent;
    },

    context: {
      nodePath: "",
      treePath: "",
      repoRoot: "",
      predicate: "",
      depth: 0,
      nodeType: null,
      confidence: null,
      prdSeed: null,
      proposedChildren: [],
      reasoning: null,
      childCount: 0,
      childrenSatisfied: 0,
      childrenPruned: 0,
      learnings: null,
      lastError: null,
    },

    initial: "idle",

    states: {
      // =====================================================================
      // IDLE — predicate.md exists, nothing else
      // Entry: node just created by parent's SUBDIVIDE
      // =====================================================================
      idle: {
        on: {
          DISCOVER: "discovering",
        },
      },

      // =====================================================================
      // DISCOVERING — evaluator subagent running
      // Reads predicate + repo context, classifies branch vs leaf
      // =====================================================================
      discovering: {
        on: {
          DISCOVERY_COMPLETE: [
            {
              guard: "isUnachievable",
              target: "awaitingPruneConfirmation",
            },
            {
              guard: "isAchievable",
              target: "discovered",
            },
          ],
          DISCOVERY_ERROR: {
            target: "idle",
          },
        },
      },

      // =====================================================================
      // DISCOVERED — discovery.md written, nodeType known
      // Human gate: confirm branch vs leaf before forking
      // Persist-before-act: discovery.md written on entry
      // =====================================================================
      discovered: {
        on: {
          CLASSIFY_BRANCH: "decomposing",
          CLASSIFY_LEAF: "specifying",
          // Human disagrees — re-run discovery
          DISCOVER: "discovering",
        },
      },

      // =====================================================================
      // BRANCH PATH
      // =====================================================================

      /**
       * DECOMPOSING — generating children from proposed_children
       * Human validates the decomposition before children are created
       */
      decomposing: {
        on: {
          DECOMPOSITION_ACCEPTED: "subdivided",
          DECOMPOSITION_REJECTED: "decomposing",
          PRUNE_CONFIRMED: "pruned",
        },
      },

      /**
       * SUBDIVIDED — children exist, state derived from them
       * This node waits until all children reach terminal state
       * active_node pointer moves into children; ASCEND returns here
       */
      subdivided: {
        on: {
          CHILDREN_SATISFIED: [
            {
              guard: "allChildrenTerminal",
              target: "awaitingApproval",
            },
            {
              // Some children still pending — stay
              target: "subdivided",
            },
          ],
          SUBDIVIDE: "decomposing",
          APPROVE: "satisfied",
          PRUNE_CONFIRMED: "pruned",
        },
      },

      // =====================================================================
      // LEAF PATH
      // =====================================================================

      /**
       * SPECIFYING — writing prd.md from discovery's prd_seed
       * Human gate: validates PRD before sprint begins
       */
      specifying: {
        on: {
          PRD_READY: "specified",
        },
      },

      /**
       * SPECIFIED — prd.md written, awaiting human approval
       * Prevents wasted sprint effort on wrong spec
       */
      specified: {
        on: {
          PRD_ACCEPTED: "planning",
          PRD_REJECTED: "specifying",
          PRUNE_CONFIRMED: "pruned",
        },
      },

      /**
       * PLANNING — /fractal:planning running
       * Produces plan.md with verifiable deliverables
       */
      planning: {
        on: {
          PLAN_DONE: "planned",
        },
      },

      /**
       * PLANNED — plan.md exists, awaiting delivery
       * Idempotency checkpoint
       */
      planned: {
        on: {
          DELIVER: "executing",
        },
      },

      /**
       * EXECUTING — /fractal:delivery running
       * Subagents execute plan in parallel batches
       */
      executing: {
        on: {
          DELIVER_DONE: "executed",
        },
      },

      /**
       * EXECUTED — results.md exists
       * Idempotency checkpoint
       */
      executed: {
        on: {
          REVIEW: "reviewing",
        },
      },

      /**
       * REVIEWING — /fractal:review running
       * Five outcomes: approved, back-to-delivery, back-to-planning,
       * back-to-discovery, back-to-fractal
       */
      reviewing: {
        on: {
          REVIEW_DONE: "reviewed",
          PLAN: "planning",
          DELIVER: "executing",
          DISCOVER: "discovering", // back-to-discovery
        },
      },

      /**
       * REVIEWED — review.md exists
       * Final human gate before ship
       */
      reviewed: {
        on: {
          SHIP: "shipping",
          REJECT: "executing",
        },
      },

      /**
       * SHIPPING — /fractal:ship running
       * PR, CI, deploy, cleanup
       */
      shipping: {
        on: {
          SHIP_DONE: "awaitingApproval",
        },
      },

      /**
       * AWAITING APPROVAL — ship complete, human validates predicate
       * "O predicado foi satisfeito?"
       */
      awaitingApproval: {
        on: {
          APPROVE: "satisfied",
          REJECT: "discovering", // re-evaluate from scratch
          PRUNE_CONFIRMED: "pruned",
        },
      },

      // =====================================================================
      // CROSS-CUTTING
      // =====================================================================

      /**
       * AWAITING PRUNE CONFIRMATION — evaluator says unachievable
       * Agent never prunes autonomously
       */
      awaitingPruneConfirmation: {
        on: {
          PRUNE_CONFIRMED: "pruned",
          PRUNE_DENIED: "discovering", // re-discover with additional context
        },
      },

      // =====================================================================
      // TERMINAL
      // =====================================================================

      /** SATISFIED — predicate achieved and human-validated */
      satisfied: { type: "final" },

      /** PRUNED — predicate abandoned */
      pruned: { type: "final" },
    },
  },
  {
    guards: {
      isAchievable: (_, event) => (event as any).achievable === true,
      isUnachievable: (_, event) => (event as any).achievable === false,
      allChildrenTerminal: ({ context }) => {
        const terminal = context.childrenSatisfied + context.childrenPruned;
        return context.childCount > 0 && terminal === context.childCount;
      },
    },
  }
);

// ---------------------------------------------------------------------------
// Idempotency bridge: filesystem → XState state
//
// The orchestrator derives the initial XState state from artifacts on disk:
//
//   predicate.md only                          → idle
//   discovery.md exists (branch)               → discovered or subdivided
//   discovery.md exists (leaf, no prd)         → discovered
//   discovery.md + prd.md                      → specified
//   plan.md                                    → planned
//   plan.md + results.md                       → executed
//   plan.md + results.md + review.md           → reviewed
//   status: satisfied                          → satisfied
//   status: pruned                             → pruned
//   children dirs exist                        → subdivided
//
// This mapping is the bridge between the filesystem-as-state model and
// the formal XState machine. fractal-state.sh computes these signals.
// ---------------------------------------------------------------------------

export type OpenPredicaTreeNodeMachine = typeof openPredicaTreeNode;
