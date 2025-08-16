'use client';

import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from 'recharts';
import { VaultStats } from '@/types/contracts';

interface AllocationPieProps {
  vaultStats: VaultStats | null;
}

const COLORS = {
  base: '#10B981',    // Green
  katana: '#F59E0B',  // Orange
  zircuit: '#8B5CF6', // Purple
  idle: '#9CA3AF',    // Gray
};

export function AllocationPie({ vaultStats }: AllocationPieProps) {
  if (!vaultStats) {
    return (
      <div className="h-48 flex items-center justify-center">
        <p className="text-gray-500 text-sm">No allocation data</p>
      </div>
    );
  }

  const data = vaultStats.chainAllocations.map(allocation => ({
    name: allocation.name,
    value: allocation.percentage,
    color: COLORS[allocation.chainId as keyof typeof COLORS] || COLORS.idle,
  }));

  // Add idle allocation if any
  const totalAllocated = data.reduce((sum, item) => sum + item.value, 0);
  if (totalAllocated < 100) {
    data.push({
      name: 'Idle',
      value: 100 - totalAllocated,
      color: COLORS.idle,
    });
  }

  const CustomTooltip = ({ active, payload }: { active?: boolean; payload?: any[] }) => {
    if (active && payload && payload[0]) {
      return (
        <div className="bg-white px-3 py-2 rounded-lg shadow-lg border border-gray-200">
          <p className="text-sm font-medium">{payload[0].name}</p>
          <p className="text-sm text-gray-600">{payload[0].value.toFixed(1)}%</p>
        </div>
      );
    }
    return null;
  };

  return (
    <ResponsiveContainer width="100%" height={192}>
      <PieChart>
        <Pie
          data={data}
          cx="50%"
          cy="50%"
          innerRadius={60}
          outerRadius={80}
          paddingAngle={2}
          dataKey="value"
        >
          {data.map((entry, index) => (
            <Cell key={`cell-${index}`} fill={entry.color} />
          ))}
        </Pie>
        <Tooltip content={<CustomTooltip />} />
      </PieChart>
    </ResponsiveContainer>
  );
}