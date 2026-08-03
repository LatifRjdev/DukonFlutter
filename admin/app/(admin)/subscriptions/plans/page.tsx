'use client';

import { useState, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Save, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { Separator } from '@/components/ui/separator';
import { api } from '@/lib/api';
import { Plan } from '@/lib/types';
import { toast } from 'sonner';

const PLAN_CONFIGS = [
  { key: 'START', label: 'START', color: 'border-gray-300' },
  { key: 'BUSINESS', label: 'BUSINESS', color: 'border-blue-300' },
  { key: 'PREMIUM', label: 'PREMIUM', color: 'border-purple-400' },
];

const FEATURE_LABELS: Record<string, string> = {
  hasReportsAll: 'Расширенные отчёты',
  hasExport: 'Экспорт данных',
  hasTelegram: 'Telegram бот',
  hasAllPush: 'Push-уведомления',
  hasDelivery: 'Доставка',
  hasInventory: 'Инвентаризация',
  hasEcommerceIntegration: 'Интернет-магазин',
};

function PlanCard({ plan, onSave }: { plan: Plan; onSave: (p: Plan) => void }) {
  const [edited, setEdited] = useState<Plan>(plan);
  const [dirty, setDirty] = useState(false);

  useEffect(() => {
    setEdited(plan);
    setDirty(false);
  }, [plan]);

  const update = <K extends keyof Plan>(key: K, value: Plan[K]) => {
    setEdited((prev) => ({ ...prev, [key]: value }));
    setDirty(true);
  };

  const config = PLAN_CONFIGS.find((c) => c.key === plan.name) || PLAN_CONFIGS[0];

  return (
    <Card className={`border-2 ${config.color}`}>
      <CardHeader className="pb-2">
        <CardTitle className="text-lg">{plan.name}</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* Numeric fields */}
        <div className="space-y-3">
          {(
            [
              ['price', 'Цена (сом/месяц)'],
              ['maxStores', 'Макс. магазинов'],
              ['maxProducts', 'Макс. товаров'],
              ['maxStaff', 'Макс. сотрудников'],
              ['maxDiscounts', 'Макс. скидок'],
            ] as [keyof Plan, string][]
          ).map(([key, label]) => (
            <div key={key} className="grid grid-cols-2 items-center gap-2">
              <Label className="text-sm">{label}</Label>
              <Input
                type="number"
                min="0"
                value={edited[key] as number}
                onChange={(e) => update(key, Number(e.target.value) as Plan[keyof Plan])}
                className="h-8"
              />
            </div>
          ))}
        </div>

        <Separator />

        {/* Feature toggles */}
        <div className="space-y-3">
          {Object.entries(FEATURE_LABELS).map(([key, label]) => (
            <div key={key} className="flex items-center justify-between">
              <Label className="text-sm cursor-pointer" htmlFor={`${plan.id}-${key}`}>
                {label}
              </Label>
              <Switch
                id={`${plan.id}-${key}`}
                checked={edited[key as keyof Plan] as boolean}
                onCheckedChange={(checked) =>
                  update(key as keyof Plan, checked as Plan[keyof Plan])
                }
              />
            </div>
          ))}
        </div>

        <Button
          className="w-full"
          disabled={!dirty}
          onClick={() => onSave(edited)}
        >
          <Save className="mr-2 h-4 w-4" />
          Сохранить
        </Button>
      </CardContent>
    </Card>
  );
}

export default function PlansPage() {
  const queryClient = useQueryClient();

  const { data: plans = [], isLoading } = useQuery<Plan[]>({
    queryKey: ['plans'],
    queryFn: () => api.get('/admin/plans'),
  });

  const saveMutation = useMutation({
    mutationFn: (plan: Plan) => api.put(`/admin/plans/${plan.id}`, plan),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['plans'] });
      toast.success('Тариф сохранён');
    },
    onError: () => toast.error('Ошибка сохранения тарифа'),
  });

  if (isLoading) {
    return (
      <div className="grid grid-cols-3 gap-6">
        {[1, 2, 3].map((i) => (
          <div key={i} className="h-96 animate-pulse rounded-lg bg-slate-100" />
        ))}
      </div>
    );
  }

  // If no plans from API, show placeholders
  const displayPlans =
    plans.length > 0
      ? plans
      : PLAN_CONFIGS.map((c, i) => ({
          id: c.key,
          name: c.key,
          price: i === 0 ? 49 : i === 1 ? 99 : 199,
          maxStores: i === 0 ? 1 : i === 1 ? 3 : 10,
          maxProducts: i === 0 ? 100 : i === 1 ? 500 : 99999,
          maxStaff: i === 0 ? 2 : i === 1 ? 5 : 20,
          maxDiscounts: i === 0 ? 5 : i === 1 ? 20 : 99999,
          hasReportsAll: i > 0,
          hasExport: i > 0,
          hasTelegram: i > 1,
          hasAllPush: i > 1,
          hasDelivery: i > 1,
          hasInventory: i === 2,
          hasEcommerceIntegration: i === 2,
        }));

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Тарифы</h1>
        <p className="text-muted-foreground text-sm mt-1">
          Настройка параметров тарифных планов
        </p>
      </div>

      {saveMutation.isPending && (
        <div className="flex items-center gap-2 text-sm text-muted-foreground">
          <Loader2 className="h-4 w-4 animate-spin" />
          Сохранение...
        </div>
      )}

      <div className="grid grid-cols-3 gap-6">
        {displayPlans.map((plan) => (
          <PlanCard
            key={plan.id}
            plan={plan}
            onSave={(p) => saveMutation.mutate(p)}
          />
        ))}
      </div>
    </div>
  );
}
