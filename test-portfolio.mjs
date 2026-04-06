import { getCollection } from 'astro:content';

const portfolioEntries = await getCollection('portfolio');
console.log('Portfolio IDs:');
portfolioEntries.forEach(entry => {
  console.log(entry.id);
});
