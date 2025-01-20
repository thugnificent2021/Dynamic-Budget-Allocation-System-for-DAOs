import { describe, it, beforeEach, expect } from 'vitest';

// Mocking the Dynamic Budget Allocation System for testing purposes
const mockBudgetSystem = {
  state: {
    treasuryBalance: 0 as number,
    totalAllocations: 0 as number,
    contractOwner: '' as string,
    budgets: new Map<string, { balance: number; performanceScore: number }>(),
  },
  initializeTreasury: (amount: number, sender: string) => {
    if (sender !== mockBudgetSystem.state.contractOwner) {
      return { value: "ERR-NOT-AUTHORIZED" };
    }
    mockBudgetSystem.state.treasuryBalance = amount;
    return { value: true };
  },
  allocateBudget: (project: string, amount: number, initialScore: number, sender: string) => {
    if (sender !== mockBudgetSystem.state.contractOwner) {
      return { value: "ERR-NOT-AUTHORIZED" };
    }
    if (amount > mockBudgetSystem.state.treasuryBalance) {
      return { value: "ERR-INVALID-AMOUNT" };
    }
    mockBudgetSystem.state.budgets.set(project, { balance: amount, performanceScore: initialScore });
    mockBudgetSystem.state.treasuryBalance -= amount;
    mockBudgetSystem.state.totalAllocations += amount;
    return { value: true };
  },
  getProjectBudget: (project: string) => {
    return mockBudgetSystem.state.budgets.get(project) || null;
  },
  getTreasuryBalance: () => {
    return mockBudgetSystem.state.treasuryBalance;
  },
};

describe('Dynamic Budget Allocation System', () => {
  let contractOwner: string, nonOwner: string;

  beforeEach(() => {
    // Initialize mock state
    contractOwner = 'ST1234...';
    nonOwner = 'ST5678...';
    mockBudgetSystem.state = {
      treasuryBalance: 0,
      totalAllocations: 0,
      contractOwner: contractOwner,
      budgets: new Map(),
    };
  });

  it('should allow the owner to initialize the treasury', () => {
    const result = mockBudgetSystem.initializeTreasury(1000, contractOwner);
    expect(result).toEqual({ value: true });
    expect(mockBudgetSystem.state.treasuryBalance).toBe(1000);
  });

  it('should prevent non-owners from initializing the treasury', () => {
    const result = mockBudgetSystem.initializeTreasury(1000, nonOwner);
    expect(result).toEqual({ value: "ERR-NOT-AUTHORIZED" });
    expect(mockBudgetSystem.state.treasuryBalance).toBe(0);
  });

  it('should allow the owner to allocate a budget', () => {
    mockBudgetSystem.initializeTreasury(1000, contractOwner);
    const result = mockBudgetSystem.allocateBudget('ST9999...', 500, 80, contractOwner);
    expect(result).toEqual({ value: true });
    expect(mockBudgetSystem.state.budgets.get('ST9999...')).toEqual({ balance: 500, performanceScore: 80 });
    expect(mockBudgetSystem.state.treasuryBalance).toBe(500);
    expect(mockBudgetSystem.state.totalAllocations).toBe(500);
  });

  it('should prevent non-owners from allocating a budget', () => {
    mockBudgetSystem.initializeTreasury(1000, contractOwner);
    const result = mockBudgetSystem.allocateBudget('ST9999...', 500, 80, nonOwner);
    expect(result).toEqual({ value: "ERR-NOT-AUTHORIZED" });
    expect(mockBudgetSystem.state.budgets.has('ST9999...')).toBe(false);
  });

  it('should prevent allocation exceeding the treasury balance', () => {
    mockBudgetSystem.initializeTreasury(1000, contractOwner);
    const result = mockBudgetSystem.allocateBudget('ST9999...', 1500, 80, contractOwner);
    expect(result).toEqual({ value: "ERR-INVALID-AMOUNT" });
    expect(mockBudgetSystem.state.budgets.has('ST9999...')).toBe(false);
    expect(mockBudgetSystem.state.treasuryBalance).toBe(1000);
  });

  it('should retrieve the correct budget for a project', () => {
    mockBudgetSystem.initializeTreasury(1000, contractOwner);
    mockBudgetSystem.allocateBudget('ST9999...', 500, 80, contractOwner);
    const projectBudget = mockBudgetSystem.getProjectBudget('ST9999...');
    expect(projectBudget).toEqual({ balance: 500, performanceScore: 80 });
  });

  it('should return null for a non-existent project budget', () => {
    const projectBudget = mockBudgetSystem.getProjectBudget('ST9999...');
    expect(projectBudget).toBeNull();
  });

  it('should retrieve the correct treasury balance', () => {
    mockBudgetSystem.initializeTreasury(1000, contractOwner);
    expect(mockBudgetSystem.getTreasuryBalance()).toBe(1000);
  });

  it('should update the treasury balance after allocation', () => {
    mockBudgetSystem.initializeTreasury(1000, contractOwner);
    mockBudgetSystem.allocateBudget('ST9999...', 500, 80, contractOwner);
    expect(mockBudgetSystem.getTreasuryBalance()).toBe(500);
  });
});
