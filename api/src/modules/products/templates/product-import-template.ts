import * as ExcelJS from 'exceljs';

export async function generateImportTemplate(): Promise<Buffer> {
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet('Товары');

  sheet.columns = [
    { header: 'Название *', key: 'name', width: 30 },
    { header: 'Штрихкод', key: 'barcode', width: 20 },
    { header: 'Категория', key: 'category', width: 20 },
    { header: 'Цена закупки', key: 'purchasePrice', width: 15 },
    { header: 'Цена продажи *', key: 'salePrice', width: 15 },
    { header: 'Количество', key: 'quantity', width: 12 },
    { header: 'Единица', key: 'unit', width: 12 },
    { header: 'Описание', key: 'description', width: 40 },
  ];

  sheet.getRow(1).font = { bold: true };
  sheet.getRow(1).fill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FFE8EAF6' },
  };

  sheet.addRow({
    name: 'Пример товара',
    barcode: '4901234567890',
    category: 'Одежда',
    purchasePrice: 100,
    salePrice: 150,
    quantity: 10,
    unit: 'шт',
    description: 'Описание товара',
  });

  const buffer = await workbook.xlsx.writeBuffer();
  return Buffer.from(buffer);
}
