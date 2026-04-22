'use client';

import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { RegistrationPoint } from '@/lib/types';

interface RegistrationsChartProps {
  data: RegistrationPoint[];
}

export function RegistrationsChart({ data }: RegistrationsChartProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Регистрации за 30 дней</CardTitle>
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={250}>
          <BarChart data={data}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
            <XAxis
              dataKey="date"
              tick={{ fontSize: 11 }}
              tickFormatter={(v) => v.slice(5)}
            />
            <YAxis tick={{ fontSize: 11 }} />
            <Tooltip />
            <Legend />
            <Bar dataKey="users" name="Пользователи" fill="#3b82f6" />
            <Bar dataKey="stores" name="Магазины" fill="#10b981" />
          </BarChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}
